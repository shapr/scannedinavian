{ pkgs, config, ... }:
let
  ref = name: "\${${name}}";
  bucketARN = bucket: "arn:aws:s3:::${bucket}";

  website_domain = "as.ynchrono.us";

  websiteBucket = "website-${website_domain}";
  loggingBucket = "${websiteBucket}-logs";

  s3-bucket-website-policy = builtins.toJSON
    { "Version" = "2012-10-17";
      "Statement" = [
        { "Sid" = "PublicReadGetObject";
          "Effect" = "Allow";
          "Principal" = "*";
          "Action" = "s3:GetObject";
          "Resource" = "${bucketARN websiteBucket}/*";
        }
      ];
    };

  template-dir = pkgs.fetchFromGitHub {
    owner = "hashicorp";
    repo = "terraform-template-dir";
    rev = "v1.0.2";
    sha256 = "sha256-9j2/oa5esy79g5YkwdhTSZUvXwHgj0rOUNKGDn4hXUY=";
  };
in
{
  provider.aws = [
    { profile = "personal";
      region = "us-east-1";
    }
  ];

  resource.aws_s3_bucket.website = {
    bucket = websiteBucket;
  };

  resource.aws_s3_bucket.logs = {
    bucket = loggingBucket;
  };

  resource.aws_s3_bucket_acl.logs = {
    inherit (config.resource.aws_s3_bucket.logs) bucket;
    acl = "log-delivery-write";
    # Make sure ownership controls are set or we can't set the ACL.
    depends_on = [ "aws_s3_bucket_ownership_controls.logs" ];
  };


  # Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
  resource.aws_s3_bucket_ownership_controls.logs = {
    inherit (config.resource.aws_s3_bucket.logs) bucket;
    rule = {
      object_ownership = "BucketOwnerPreferred";
    };
  };

  resource.aws_s3_bucket_website_configuration.website = {
    bucket = config.resource.aws_s3_bucket.website.bucket;

    index_document.suffix = "index.html";
    error_document.key = "404.html";

  };

  resource.aws_s3_bucket_cors_configuration.website = {
    bucket = config.resource.aws_s3_bucket.website.bucket;
    depends_on = [ "aws_s3_bucket.website" ];

    cors_rule = [
      { allowed_headers = ["*"];
        allowed_methods = ["GET"];
        allowed_origins = ["https://${website_domain}"];
        expose_headers  = ["ETag"];
        max_age_seconds = 60;
      }
    ];
  };

  resource.aws_s3_bucket_ownership_controls.website = {
    bucket = config.resource.aws_s3_bucket.website.bucket;
    rule = [
      { object_ownership = "BucketOwnerPreferred"; }
    ];
  };

  resource.aws_s3_bucket_public_access_block.website = {
    bucket = config.resource.aws_s3_bucket.website.bucket;

    block_public_acls       = false;
    block_public_policy     = false;
    ignore_public_acls      = false;
    restrict_public_buckets = false;
  };

  resource.aws_s3_bucket_acl.website = {
    bucket = config.resource.aws_s3_bucket.website.bucket;

    depends_on = [
      "aws_s3_bucket_ownership_controls.website"
      "aws_s3_bucket_public_access_block.website"
    ];

    acl    = "public-read";
  };

  resource.aws_acm_certificate.ssl_certificate = {
    provider = "aws";
    domain_name = website_domain;
    subject_alternative_names = [website_domain];
    validation_method = "DNS";
    lifecycle = [
      { create_before_destroy = true;
      }
    ];
    options = [
      { certificate_transparency_logging_preference = "ENABLED";
      }
    ];
  };

  module.website_domain_validation = {
    source = builtins.toString ./dns_domain_validation;
    zone_id = config.resource.aws_route53_zone.ynchronous "zone_id";
    domain_validation_options = config.resource.aws_acm_certificate.ssl_certificate "domain_validation_options";
  };

  resource.aws_acm_certificate_validation.cert_validation = {
    provider = "aws";
    certificate_arn = config.resource.aws_acm_certificate.ssl_certificate "arn";
    validation_record_fqdns = ref "module.website_domain_validation.validation_record_fqdns";
  };

  resource.aws_iam_role.cloudfront_logging_role = {
    name = "cloudfront-logging-role";

    assume_role_policy = builtins.toJSON
      { Version = "2012-10-17";
        Statement = [{
          Action = "sts:AssumeRole";
          Effect = "Allow";
          Principal = {
            Service = "cloudfront.amazonaws.com";
          };
        }];
      };
  };

  resource.aws_iam_role_policy.cloudfront_logging_policy = {
    name = "cloudfront-logging-policy";
    role = config.resource.aws_iam_role.cloudfront_logging_role "id";

    policy = builtins.toJSON {
      Version = "2012-10-17";
      Statement = [{
        Action = "s3:PutObject";
        Effect = "Allow";
        Resource = [
          (bucketARN loggingBucket)
          "${bucketARN loggingBucket}/*"
        ];
      }];
    };
  };

  resource.aws_cloudfront_distribution.www_s3_distribution = {
    origin = [
      { domain_name = config.resource.aws_s3_bucket_website_configuration.website "website_endpoint";
        origin_id = config.resource.aws_s3_bucket_website_configuration.website "website_domain";

        custom_origin_config = [
          { http_port = 80;
            https_port = 443;
            origin_protocol_policy = "http-only";
            origin_ssl_protocols = ["TLSv1.1"];
          }
        ];
      }
    ];
    enabled = true;
    is_ipv6_enabled = true;
    default_root_object = "index.html";

    aliases = ["as.ynchrono.us"];

    logging_config = {
      bucket = config.resource.aws_s3_bucket.logs "bucket_domain_name";
      prefix = "as.ynchrono.us-cloudfront/";
    };

    viewer_certificate = [
      { acm_certificate_arn = config.resource.aws_acm_certificate_validation.cert_validation "certificate_arn";
        ssl_support_method = "sni-only";
        # minimum_protocol_version = "TLSv1.1_2016";
      }
    ];

    default_cache_behavior = [
      { allowed_methods  = ["GET" "HEAD"];
        cached_methods   = ["GET" "HEAD"];
        target_origin_id = (builtins.head config.resource.aws_cloudfront_distribution.www_s3_distribution.origin).origin_id;

        forwarded_values = [
          { query_string = true;
            cookies = [
              { forward = "none"; }
            ];
            headers = ["Origin"];
          }
        ];

        viewer_protocol_policy = "redirect-to-https";
        min_ttl                = 0;
        default_ttl            = 300;
        max_ttl                = 300;

        function_association = {
          event_type = "viewer-request";
          function_arn = config.resource.aws_cloudfront_function.redirects "arn";
        };
      }
    ];

    restrictions = [
      { geo_restriction = [
          { restriction_type = "none"; }
        ];
      }
    ];
  };

  resource.aws_cloudfront_function.redirects = {
    name    = "redirect_blogger_slugs_to_new_slugs";
    runtime = "cloudfront-js-1.0";
    comment = "redirect from old blogger post locations to new locations";
    publish = true;
    code    = builtins.readFile ./redirect.js;
  };

  resource.aws_route53_zone.ynchronous = {
    name = "ynchrono.us";
  };

  resource.aws_route53_record.website = {
    zone_id = config.resource.aws_route53_zone.ynchronous "zone_id";
    name = website_domain;
    type = "A";

    alias = [
      { name = ref"aws_cloudfront_distribution.www_s3_distribution.domain_name";
        zone_id = ref"aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id";
        evaluate_target_health = false;
      }
    ];
  };

  module.website_content = {
    source = builtins.toString template-dir;
    base_dir = builtins.toString ./result/dist;
  };

  resource.aws_s3_object.website_files = {
    for_each = ref "module.website_content.files";
    bucket = config.resource.aws_s3_bucket.website.bucket;

    key          = ref "each.key";
    acl          = "public-read";
    content_type = ref "each.value.content_type";

    # The template-dir module guarantees that only one of these two attributes
    # will be set for each file, depending on whether it is an in-memory
    # template rendering result or a static file on disk.
    source  = ref "each.value.source_path";
    content = ref "each.value.content";

    # Unless the bucket has encryption enabled, the ETag of each object is an
    # MD5 hash of that object.
    etag = ref "each.value.digests.md5";
  };

  output."nameservers".value = config.resource.aws_route53_zone.ynchronous "name_servers";
}

'use strict';

var redirects = {
    "/2006/03/wrote-program-to-email-weekly-trac_12.html": "/wrote-a-program-to-email-weekly-trac-ticket-cha.html",
    "/2007/12/filesystem-structure-of-python-project_21.html": "/filesystem-structure-of-a-python-project.html",
    "/2009/09/twisted-web-in-60-seconds-custom_24.html": "twisted-web-in-60-seconds-custom-response-codes.html",
    "/2009/09/twisted-web-in-60-seconds-serve-static_16.html": "/twisted-web-in-60-seconds-serve-static-content-from-a-directory.html",
    "/2009/09/twisted-web-in-60-seconds-static-url_19.html": "/twisted-web-in-60-seconds-static-url-dispatch.html",
    "/2009/10/twisted-web-in-60-seconds-interrupted_18.html": "/twisted-web-in-60-seconds-interrupted-responses.html",
    "/2009/10/twisted-web-in-60-seconds-logging_22.html": "/twisted-web-in-60-seconds-logging-errors.html",
    "/2009/10/twisted-web-in-60-seconds-rpy-scripts_02.html": "/twisted-web-in-60-seconds-rpy-scripts-or-how-to-save-yourself-some-typing.html",
    "/2009/10/twisted-web-in-60-seconds-wsgi_25.html": "/twisted-web-in-60-seconds-wsgi.html",
    "/2009/11/twisted-web-in-60-seconds-http_06.html": "/twisted-web-in-60-seconds-http-authentication.html",
    "/2009/11/twisted-web-in-60-seconds-session_18.html": "/twisted-web-in-60-seconds-session-basics.html",
    "/2009/11/twisted-web-in-60-seconds-storing_28.html": "/twisted-web-in-60-seconds-storing-objects-in-the-session.html",
    "/2009/12/twisted-web-in-60-seconds-session_01.html": "/twisted-web-in-60-seconds-session-endings.html",
    "/2011/04/twisted-conch-in-60-seconds-accepting.html": "/twisted-conch-in-60-seconds-accepting-input.html",
    "/2011/04/twisted-conch-in-60-seconds-detecting.html": "/twisted-conch-in-60-seconds-detecting-eof-on-input.html",
    "/2011/04/twisted-conch-in-60-seconds-trivial.html": "/twisted-conch-in-60-seconds-a-trivial-channel.html",
    "/2011/05/planting-trees-day-6.html": "/planting-trees-day-6.html",
    "/2012/02/side-project-crop-planning-software.html": "/side-project-crop-planning-software.html",
    "/2014/05/de-cruft-divmod-imaginary-update.html": "/de-cruft-divmod-imaginary-update.html",
    "/2014/05/update-on-divmod-imaginary.html": "/update-on-divmod-imaginary.html",
    "/2014/12/asynchronous-object-initialization.html": "/asynchronous-object-initialization-patterns-and-antipatterns.html",
    "/2017/09/ssh-to-ec2-refrain.html": "/ssh-to-ec2-refrain.html",
    "/zzzz": "" /* sort at the end without a comma */
}

function handler(event) {
  var request = event.request;
  var location = redirects[request.uri];
  if (location === undefined) { return request; }
  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: {location: {value: location}}
  }
}

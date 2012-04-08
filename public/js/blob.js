function getSource(user, repo, id, cont) {
    $.jsonp({ url: "https://api.github.com/repos/" + user + "/" + repo + "/git/blobs/" + id + "?callback=?",
              success: function(result) {
                  encoded = result.data.content;
                  encoded = encoded.replace(/\s/g, '');
                  source = Base64.decode(encoded);
                  $("#source").text(source);
                  cont();
              }});
}

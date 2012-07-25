function CommentModel() {
    this.initialize.apply(this, arguments);
}

CommentModel.prototype = {
    initialize: function() {
        this.comments = [];
    },

    setComment: function(index, text) {
        if (text.length > 0) {
            this.comments[index] = text;
        }
    },

    deleteComment: function(index) {
        delete this.comments[index];
    },

    getComment: function(index) {
        return this.comments[index];
    },

    hasComment: function(index) {
        return (index in this.comments);
    },

    forEach: function(proc) {
        this.comments.forEach(proc);
    }
};

function PersistentCommentModel() {
    this.initialize.apply(this, arguments);
}

PersistentCommentModel.prototype = {
    initialize: function(model, project, revision, path) {
        this.model = model;
        this.commentsApiUrl = ['/projects', project, revision, 'files', path, 'comments'].join('/');
    },

    getComment: function(index) {
        return this.model.getComment(index);
    },

    setComment: function(index, text, cont) {
        if (text.length > 0) {
            this.model.setComment(index, text);
            $.ajax({url: this.commentsApiUrl + '/new',
                    type: 'POST',
                    contentType: 'application/json',
                    data: JSON.stringify({ line: index, text: text }),
                    processData: false,
                    dataType: 'json'
                   }).done(function(data) {
                       cont('OK');  // temp
                   });
        } else {
            cont('NG');
        }
    },

    deleteComment: function(index, cont) {
        this.model.deleteComment(index);
        $.ajax({url: this.commentsApiUrl + '/' + index,
               type: 'DELETE'
              }).done(function(data) {
                  cont('OK');  // temp
              });
    },

    forEach: function(proc) {
        this.model.forEach(proc);
    },

    getAllComments: function(cont) {
        var self = this;
        $.getJSON(self.commentsApiUrl,
                  function(data) {
                      data.forEach(function(e) {
                          self.model.setComment(e.line, e.text);
                      });
                      cont('OK');
                  }
        );
    }
};

function CommentView() {
    this.initialize.apply(this, arguments);
}

CommentView.prototype = {
    initialize: function(model) {
        this.model = model;
        this.cursorIndex = -1;
        this.editingIndex = -1;
        this._setup();
        this._populate();
    },
    
    _setup: function() {
        this.commentEditElem = $("#comment_edit");
        this.commentElem = $("[name='comment']");
        var self = this;

        var linesElem = $("#source ol");
        linesElem.on("mouseover", "li", function(ev) {
            self.cursorIndex = linesElem.children().index(this);
            var ofs = $(this).offset();
            ofs.left -= 30;
            $("#cursor").offset(ofs).show();
        });
        $("#cursor").on("click", function(ev) {
            self.editingIndex = self.cursorIndex;
            var li = linesElem.children()[self.cursorIndex];
            $(li).find("[name='comment']").remove();
            $(li).prepend(self.commentEditElem.show());
            var commentText = self.model.getComment(self.editingIndex);
            self.commentEditElem.find("textarea").val(commentText).focus();
        });
        this.commentEditElem.on("blur", "textarea", function(ev) {
            var commentText = $(this).val();
            if (commentText.length > 0) {
                var commentElemClone = self.commentElem.clone(false);
                commentElemClone.find("[name='container']").text(commentText);
                self.commentEditElem.after(commentElemClone);
                self.model.setComment(self.editingIndex, commentText, function(status) {});
            } else {
                self.model.deleteComment(self.editingIndex, function(status) {});
            }
            $(this).val("");
            self.commentEditElem.detach();
            self.editingIndex = -1;
        });
    },

    _populate: function() {
        var self = this;
        this.model.forEach(function(value, key) {
            var text = value;
            var line = key;
            var linesElem = $("#source ol");
            var li = linesElem.children()[line];
            $(li).find("[name='comment']").remove();
            var commentElemClone = self.commentElem.clone(false);
            commentElemClone.find("[name='container']").text(text);
            $(li).prepend(commentElemClone);
        });
    }
};

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

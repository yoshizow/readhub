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
    initialize: function(model, user_name, proj_name, revision, path) {
        this.model = model;
        this.commentsApiUrl = '/' + [user_name, proj_name, revision, 'files', path, 'comments'].join('/');
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
                       var result = JSON.parse(data);
                       if (result.status == 'OK') {
                           cont('OK');
                       } else {
                           cont('NG');
                       }
                   }).fail(function() {
                       cont('NG');
                   });;
        } else {
            cont('NG');
        }
    },

    deleteComment: function(index, cont) {
        this.model.deleteComment(index);
        $.ajax({url: this.commentsApiUrl + '/' + index,
               type: 'DELETE'
              }).done(function(data) {
                  var result = JSON.parse(data);
                  if (result.status == 'OK') {
                      cont('OK');
                  } else {
                      cont('NG');
                  }
              }).fail(function() {
                  cont('NG');
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
    initialize: function(model, readonly) {
        this.model = model;
        this.readonly = readonly;
        this.cursorIndex = -1;
        this.editingIndex = -1;
        this._setup();
        this._populate();
    },
    
    _setup: function() {
        this.commentEditElem = $("#comment_edit");
        this.commentElem = $("[name='comment']");

        if (!this.readonly) {
            this._setupForWrite();
        }
    },

    _setupForWrite: function() {
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
                self.model.setComment(self.editingIndex, commentText, function(status) {
                    self._handleAPIStatus(status);
                });
            } else {
                self.model.deleteComment(self.editingIndex, function(status) {
                    self._handleAPIStatus(status);
                });
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
    },

    _handleAPIStatus: function(status) {
        if (status != 'OK') {
            this._reportError("Failed to update comment");
        }
    },

    _reportError: function(message) {
        window.alert(message);
    }
};

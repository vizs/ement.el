;;; ement-macros.el --- Ement macros                 -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Adam Porter

;; Author: Adam Porter <adam@alphapapa.net>
;; Keywords: comm

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

;;;; Requirements

(require 'map)

;;;; Debugging

(eval-and-compile
  (setq-local warning-minimum-log-level nil)
  (setq-local warning-minimum-log-level :debug))

(cl-defmacro ement-debug (&rest args)
  "Display a debug warning showing the runtime value of ARGS.
The warning automatically includes the name of the containing
function, and it is only displayed if `warning-minimum-log-level'
is `:debug' at expansion time (otherwise the macro expands to nil
and is eliminated by the byte-compiler).  When debugging, the
form also returns nil so, e.g. it may be used in a conditional in
place of nil.

Each of ARGS may be a string, which is displayed as-is, or a
symbol, the value of which is displayed prefixed by its name, or
a Lisp form, which is displayed prefixed by its first symbol.

Before the actual ARGS arguments, you can write keyword
arguments, i.e. alternating keywords and values.  The following
keywords are supported:

  :buffer BUFFER   Name of buffer to pass to `display-warning'.
  :level  LEVEL    Level passed to `display-warning', which see.
                   Default is :debug."
  (pcase-let* ((fn-name (with-current-buffer
                            (or byte-compile-current-buffer (current-buffer))
                          ;; This is a hack, but a nifty one.
                          (save-excursion
                            (beginning-of-defun)
                            (cl-second (read (current-buffer))))))
               (plist-args (cl-loop while (keywordp (car args))
                                    collect (pop args)
                                    collect (pop args)))
               ((map (:buffer buffer) (:level level)) plist-args)
               (level (or level :debug))
               (string (cl-loop for arg in args
                                concat (pcase arg
                                         ((pred stringp) "%S ")
                                         ((pred symbolp)
                                          (concat (upcase (symbol-name arg)) ":%S "))
                                         ((pred listp)
                                          (concat "(" (upcase (symbol-name (car arg)))
                                                  (pcase (length arg)
                                                    (1 ")")
                                                    (_ "...)"))
                                                  ":%S "))))))
    (when (eq :debug warning-minimum-log-level)
      `(progn
         (display-warning ',fn-name (format ,string ,@args) ,level ,buffer)
         nil))))

;;;; Macros

(defmacro ement-alist (&rest pairs)
  "Expand to an alist of the keys and values in PAIRS."
  `(list ,@(cl-loop for (key value) on pairs by #'cddr
                    collect `(cons ,key ,value))))

;;;;; Anaphoric

;; We could just depend on dash.el and use --first, and anaphora.el (only
;; on MELPA, not ELPA) has aprog1, but in order to reduce dependencies...

(defmacro ement-afirst (form list)
  "Return the first element of LIST for which FORM is non-nil.
In FORM, `it' is bound to the element being tested."
  (declare (indent 1))
  `(cl-loop for it in ,list
            ;; Avoid the `when' clause's implicit binding of `it'.
            do (when ,form
                 (cl-return it))))

(defmacro ement-aprog1 (first &rest body)
  "Like `prog1', but FIRST's value is bound to `it' around BODY."
  (declare (indent 1))
  `(let ((it ,first))
     ,@body
     it))

;;;;; Progress reporters

;; MAYBE: Submit a `with-progress-reporter' macro to Emacs.

(defalias 'ement-progress-update #'ignore
  "By default, this function does nothing.  But inside
`ement-with-progress-reporter', it's bound to a function that
updates the current progress reporter.")

(defmacro ement-with-progress-reporter (args &rest body)
  "Eval BODY with a progress reporter according to ARGS.
ARGS is a plist of these values:

  :when  If specified, a form evaluated at runtime to determine
         whether to make and update a progress reporter.  If not
         specified, the reporter is always made and updated.

  :reporter  A list of arguments passed to
             `make-progress-reporter', which see.

Around BODY, the function `ement-progress-update' is set to a
function that calls `progress-reporter-update' on the progress
reporter (or if the :when form evaluates to nil, the function is
set to `ignore').  It optionally takes a VALUE argument, and
without one, it automatically updates the value from the
reporter's min-value to its max-value."
  (declare (indent defun))
  (pcase-let* ((progress-reporter-sym (gensym))
               (progress-value-sym (gensym))
               (start-time-sym (gensym))
               ((map (:when when-form) (:reporter reporter-args)) args)
               (`(,_message ,min-value ,_max-value) reporter-args)
               (update-fn `(cl-function
                            (lambda (&optional (value (cl-incf ,progress-value-sym)))
                              (ement-debug "Updating progress reporter to" value)
                              (progress-reporter-update ,progress-reporter-sym value)))))
    `(let* ((,start-time-sym (current-time))
            (,progress-value-sym (or ,min-value 0))
            (,progress-reporter-sym ,(if when-form
                                         `(when ,when-form
                                            (make-progress-reporter ,@reporter-args))
                                       `(make-progress-reporter ,@reporter-args))))
       ;; We use `cl-letf' rather than `cl-labels', because labels expand to lambdas and funcalls,
       ;; so other functions that call `ement-progress-update' wouldn't call this definition.
       (cl-letf (((symbol-function 'ement-progress-update)
                  ,(if when-form
                       `(if ,when-form
                            ,update-fn
                          #'ignore)
                     update-fn)))
         ,@body
         (ement-debug (format "Ement: Progress reporter done (took %.2f seconds)"
                              (float-time (time-subtract (current-time) ,start-time-sym))))))))

;;;; Variables


;;;; Customization


;;;; Commands


;;;; Functions


;;;; Footer

(provide 'ement-macros)

;;; ement-macros.el ends here

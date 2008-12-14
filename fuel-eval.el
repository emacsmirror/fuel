;;; fuel-eval.el --- evaluating Factor expressions

;; Copyright (C) 2008  Jose Antonio Ortega Ruiz
;; See http://factorcode.org/license.txt for BSD license.

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Keywords: languages
;; Start date: Tue Dec 02, 2008

;;; Commentary:

;; Protocols for sending evaluations to the Factor listener.

;;; Code:

(require 'fuel-base)
(require 'fuel-syntax)
(require 'fuel-connection)


;;; Simple sexp-based representation of factor code

(defun factor (sexp)
  (cond ((null sexp) "f")
        ((eq sexp t) "t")
        ((or (stringp sexp) (numberp sexp)) (format "%S" sexp))
        ((vectorp sexp) (cons :quotation (append sexp nil)))
        ((listp sexp)
         (case (car sexp)
           (:array (factor--seq 'V{ '} (cdr sexp)))
           (:quote (format "\\ %s" (factor `(:factor ,(cadr sexp)))))
           (:quotation (factor--seq '\[ '\] (cdr sexp)))
           (:factor (format "%s" (mapconcat 'identity (cdr sexp) " ")))
           (:fuel (factor--fuel-factor (cons :rs (cdr sexp))))
           (:fuel* (factor--fuel-factor (cons :nrs (cdr sexp))))
           (t (mapconcat 'factor sexp " "))))
        ((keywordp sexp)
         (factor (case sexp
                   (:rs 'fuel-eval-restartable)
                   (:nrs 'fuel-eval-non-restartable)
                   (:in (fuel-syntax--current-vocab))
                   (:usings `(:array ,@(fuel-syntax--usings-update)))
                   (:get 'fuel-eval-set-result)
                   (t `(:factor ,(symbol-name sexp))))))
        ((symbolp sexp) (symbol-name sexp))))

(defsubst factor--seq (begin end forms)
  (format "%s %s %s" begin (if forms (factor forms) "") end))

(defsubst factor--fuel-factor (sexp)
  (factor `(,(factor--fuel-restart (nth 0 sexp))
            ,(factor--fuel-lines (nth 1 sexp))
            ,(factor--fuel-in (nth 2 sexp))
            ,(factor--fuel-usings (nth 3 sexp))
            fuel-eval-in-context)))

(defsubst factor--fuel-restart (rs)
  (unless (member rs '(:rs :nrs))
    (error "Invalid restart spec (%s)" rs))
  rs)

(defsubst factor--fuel-lines (lst)
  (cons :array (mapcar 'factor lst)))

(defsubst factor--fuel-in (in)
  (cond ((null in) :in)
        ((eq in t) "fuel-scratchpad")
        ((stringp in) in)
        (t (error "Invalid 'in' (%s)" in))))

(defsubst factor--fuel-usings (usings)
  (cond ((null usings) :usings)
        ((eq usings t) nil)
        ((listp usings) `(:array ,@usings))
        (t (error "Invalid 'usings' (%s)" usings))))



;;; Code sending:

(defvar fuel-eval--default-proc-function nil)
(defsubst fuel-eval--default-proc ()
  (and fuel-eval--default-proc-function
       (funcall fuel-eval--default-proc-function)))

(defvar fuel-eval--proc nil)

(defvar fuel-eval--sync-retort nil)

(defun fuel-eval--send/wait (code &optional timeout buffer)
  (setq fuel-eval--sync-retort nil)
  (fuel-con--send-string/wait (or fuel-eval--proc (fuel-eval--default-proc))
                              (if (stringp code) code (factor code))
                              '(lambda (s)
                                 (setq fuel-eval--sync-retort
                                       (fuel-eval--parse-retort s)))
                              timeout
                              buffer)
  fuel-eval--sync-retort)

(defun fuel-eval--send (code cont &optional buffer)
  (fuel-con--send-string (or fuel-eval--proc (fuel-eval--default-proc))
                         (if (stringp code) code (factor code))
                         `(lambda (s) (,cont (fuel-eval--parse-retort s)))
                         buffer))


;;; Retort and retort-error datatypes:

(defsubst fuel-eval--retort-make (err result &optional output)
  (list err result output))

(defsubst fuel-eval--retort-error (ret) (nth 0 ret))
(defsubst fuel-eval--retort-result (ret) (nth 1 ret))
(defsubst fuel-eval--retort-output (ret) (nth 2 ret))

(defsubst fuel-eval--retort-p (ret) (listp ret))

(defsubst fuel-eval--make-parse-error-retort (str)
  (fuel-eval--retort-make (cons 'fuel-parse-retort-error str) nil))

(defun fuel-eval--parse-retort (str)
  (save-current-buffer
    (condition-case nil
        (let ((ret (car (read-from-string str))))
          (if (fuel-eval--retort-p ret) ret (error)))
      (error (fuel-eval--make-parse-error-retort str)))))

(defsubst fuel-eval--error-name (err) (car err))

(defsubst fuel-eval--error-restarts (err)
  (cdr (assoc :restarts (fuel-eval--error-name-p err 'condition))))

(defun fuel-eval--error-name-p (err name)
  (unless (null err)
    (or (and (eq (fuel-eval--error-name err) name) err)
        (assoc name err))))

(defsubst fuel-eval--error-file (err)
  (nth 1 (fuel-eval--error-name-p err 'source-file-error)))

(defsubst fuel-eval--error-lexer-p (err)
  (or (fuel-eval--error-name-p err 'lexer-error)
      (fuel-eval--error-name-p (fuel-eval--error-name-p err 'source-file-error)
                               'lexer-error)))

(defsubst fuel-eval--error-line/column (err)
  (let ((err (fuel-eval--error-lexer-p err)))
    (cons (nth 1 err) (nth 2 err))))

(defsubst fuel-eval--error-line-text (err)
  (nth 3 (fuel-eval--error-lexer-p err)))


(provide 'fuel-eval)
;;; fuel-eval.el ends here

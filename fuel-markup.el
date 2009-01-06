;;; fuel-markup.el -- printing factor help markup

;; Copyright (C) 2009 Jose Antonio Ortega Ruiz
;; See http://factorcode.org/license.txt for BSD license.

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Keywords: languages, fuel, factor
;; Start date: Thu Jan 01, 2009 21:43

;;; Comentary:

;; Utilities for printing Factor's help markup.

;;; Code:

(require 'fuel-eval)
(require 'fuel-font-lock)
(require 'fuel-base)

(require 'button)
(require 'table)


;;; Customization:

(fuel-font-lock--defface fuel-font-lock-markup-title
  'bold fuel-help "article titles in help buffers")

(fuel-font-lock--defface fuel-font-lock-markup-heading
  'bold fuel-help "headlines in help buffers")

(fuel-font-lock--defface fuel-font-lock-markup-link
  'link fuel-help "links to topics in help buffers")

(fuel-font-lock--defface fuel-font-lock-markup-emphasis
  'italic fuel-help "emphasized words in help buffers")

(fuel-font-lock--defface fuel-font-lock-markup-strong
  'link fuel-help "bold words in help buffers")


;;; Links:

(make-variable-buffer-local
 (defvar fuel-markup--follow-link-function 'fuel-markup--echo-link))

(define-button-type 'fuel-markup--button
  'action 'fuel-markup--follow-link
  'face 'fuel-font-lock-markup-link
  'follow-link t)

(defun fuel-markup--follow-link (button)
  (when fuel-markup--follow-link-function
    (funcall fuel-markup--follow-link-function
             (button-get button 'markup-link)
             (button-get button 'markup-label)
             (button-get button 'markup-link-type))))

(defun fuel-markup--echo-link (link label type)
  (message "Link %s pointing to %s named %s" label type link))

(defun fuel-markup--insert-button (label link type)
  (let ((label (format "%s" label))
        (link (format "%s" link)))
    (insert-text-button label
                        :type 'fuel-markup--button
                        'markup-link link
                        'markup-label label
                        'markup-link-type type
                        'help-echo (format "%s (%s)" label type))))

(defun fuel-markup--article-title (name)
  (fuel-eval--retort-result
   (fuel-eval--send/wait `(:fuel* ((,name fuel-article-title :get)) "fuel"))))

(defun fuel-markup--link-at-point ()
  (let ((button (condition-case nil (forward-button 0) (error nil))))
    (when button
      (list (button-get button 'markup-link)
            (button-get button 'markup-label)
            (button-get button 'markup-link-type)))))


;;; Markup printers:

(defconst fuel-markup--printers
  '(($class-description . fuel-markup--class-description)
    ($code . fuel-markup--code)
    ($command . fuel-markup--command)
    ($contract . fuel-markup--contract)
    ($curious . fuel-markup--curious)
    ($definition . fuel-markup--definition)
    ($describe-vocab . fuel-markup--describe-vocab)
    ($description . fuel-markup--description)
    ($doc-path . fuel-markup--doc-path)
    ($emphasis . fuel-markup--emphasis)
    ($error-description . fuel-markup--error-description)
    ($errors . fuel-markup--errors)
    ($example . fuel-markup--example)
    ($examples . fuel-markup--examples)
    ($heading . fuel-markup--heading)
    ($index . fuel-markup--index)
    ($instance . fuel-markup--instance)
    ($io-error . fuel-markup--io-error)
    ($link . fuel-markup--link)
    ($links . fuel-markup--links)
    ($list . fuel-markup--list)
    ($low-level-note . fuel-markup--low-level-note)
    ($markup-example . fuel-markup--markup-example)
    ($maybe . fuel-markup--maybe)
    ($methods . fuel-markup--methods)
    ($nl . fuel-markup--newline)
    ($notes . fuel-markup--notes)
    ($parsing-note . fuel-markup--parsing-note)
    ($predicate . fuel-markup--predicate)
    ($prettyprinting-note . fuel-markup--prettyprinting-note)
    ($quotation . fuel-markup--quotation)
    ($references . fuel-markup--references)
    ($related . fuel-markup--related)
    ($see . fuel-markup--see)
    ($see-also . fuel-markup--see-also)
    ($shuffle . fuel-markup--shuffle)
    ($side-effects . fuel-markup--side-effects)
    ($slot . fuel-markup--snippet)
    ($snippet . fuel-markup--snippet)
    ($strong . fuel-markup--strong)
    ($subheading . fuel-markup--subheading)
    ($subsection . fuel-markup--subsection)
    ($synopsis . fuel-markup--synopsis)
    ($syntax . fuel-markup--syntax)
    ($table . fuel-markup--table)
    ($unchecked-example . fuel-markup--example)
    ($value . fuel-markup--value)
    ($values . fuel-markup--values)
    ($values-x/y . fuel-markup--values-x/y)
    ($var-description . fuel-markup--var-description)
    ($vocab-link . fuel-markup--vocab-link)
    ($vocab-links . fuel-markup--vocab-links)
    ($vocab-subsection . fuel-markup--vocab-subsection)
    ($vocabulary . fuel-markup--vocabulary)
    ($warning . fuel-markup--warning)
    (article . fuel-markup--article)
    (vocab-list . fuel-markup--vocab-list)))

(make-variable-buffer-local
 (defvar fuel-markup--maybe-nl nil))

(defun fuel-markup--print (e)
  (cond ((null e))
        ((stringp e) (fuel-markup--insert-string e))
        ((and (listp e) (symbolp (car e))
              (assoc (car e) fuel-markup--printers))
         (funcall (cdr (assoc (car e) fuel-markup--printers)) e))
        ((and (symbolp e)
              (assoc e fuel-markup--printers))
         (funcall (cdr (assoc e fuel-markup--printers)) e))
        ((listp e) (mapc 'fuel-markup--print e))
        ((symbolp e) (fuel-markup--print (list '$link e)))
        (t (insert (format "\n%S\n" e)))))

(defun fuel-markup--print-str (e)
  (with-temp-buffer
    (fuel-markup--print e)
    (buffer-string)))

(defun fuel-markup--maybe-nl ()
  (setq fuel-markup--maybe-nl (point)))

(defun fuel-markup--insert-newline (&optional justification nosqueeze)
  (fill-region (save-excursion (beginning-of-line) (point))
               (point)
               (or justification 'left)
               nosqueeze)
  (newline))

(defsubst fuel-markup--insert-nl-if-nb (&optional no-fill)
  (unless (eq (save-excursion (beginning-of-line) (point)) (point))
    (if no-fill (newline) (fuel-markup--insert-newline))))

(defsubst fuel-markup--put-face (txt face)
  (put-text-property 0 (length txt) 'font-lock-face face txt)
  txt)

(defun fuel-markup--insert-heading (txt &optional no-nl)
  (fuel-markup--insert-nl-if-nb)
  (delete-blank-lines)
  (unless (bobp) (newline))
  (fuel-markup--put-face txt 'fuel-font-lock-markup-heading)
  (fuel-markup--insert-string txt)
  (unless no-nl (newline)))

(defun fuel-markup--insert-string (str)
  (when fuel-markup--maybe-nl
    (newline 2)
    (setq fuel-markup--maybe-nl nil))
  (insert str))

(defun fuel-markup--article (e)
  (setq fuel-markup--maybe-nl nil)
  (insert (fuel-markup--put-face (cadr e) 'fuel-font-lock-markup-title))
  (newline 2)
  (fuel-markup--print (car (cddr e))))

(defun fuel-markup--heading (e)
  (fuel-markup--insert-heading (cadr e)))

(defun fuel-markup--subheading (e)
  (fuel-markup--insert-heading (cadr e)))

(defun fuel-markup--subsection (e)
  (fuel-markup--insert-nl-if-nb)
  (insert "  - ")
  (fuel-markup--link (cons '$link (cdr e)))
  (fuel-markup--maybe-nl))

(defun fuel-markup--vocab-subsection (e)
  (fuel-markup--insert-nl-if-nb)
  (insert "  - ")
  (fuel-markup--vocab-link (cons '$vocab-link (cdr e)))
  (fuel-markup--maybe-nl))

(defun fuel-markup--newline (e)
  (fuel-markup--insert-newline)
  (newline))

(defun fuel-markup--doc-path (e)
  (fuel-markup--insert-heading "Related topics")
  (insert "  ")
  (dolist (art (cdr e))
    (fuel-markup--insert-button (car art) (cadr art) 'article)
    (insert ", "))
  (delete-backward-char 2)
  (fuel-markup--insert-newline 'left))

(defun fuel-markup--emphasis (e)
  (when (stringp (cadr e))
    (fuel-markup--put-face (cadr e) 'fuel-font-lock-markup-emphasis)
    (insert (cadr e))))

(defun fuel-markup--strong (e)
  (when (stringp (cadr e))
    (fuel-markup--put-face (cadr e) 'fuel-font-lock-markup-strong)
    (insert (cadr e))))

(defun fuel-markup--snippet (e)
  (let ((snip (format "%s" (cadr e))))
    (insert (fuel-font-lock--factor-str snip))))

(defun fuel-markup--code (e)
  (fuel-markup--insert-nl-if-nb)
  (newline)
  (dolist (snip (cdr e))
    (if (stringp snip)
        (insert (fuel-font-lock--factor-str snip))
      (fuel-markup--print snip))
    (newline))
  (newline))

(defun fuel-markup--command (e)
  (fuel-markup--snippet (list '$snippet (nth 3 e))))

(defun fuel-markup--syntax (e)
  (fuel-markup--insert-heading "Syntax")
  (fuel-markup--print (cons '$code (cdr e)))
  (newline))

(defun fuel-markup--example (e)
  (fuel-markup--insert-newline)
  (dolist (s (cdr e))
    (fuel-markup--snippet (list '$snippet s))
    (newline)))

(defun fuel-markup--markup-example (e)
  (fuel-markup--insert-newline)
  (fuel-markup--snippet (cons '$snippet (cdr e))))

(defun fuel-markup--link (e)
  (let* ((link (nth 1 e))
         (type (or (nth 3 e) (if (symbolp link) 'word 'article)))
         (label (or (nth 2 e)
                    (and (eq type 'article)
                         (fuel-markup--article-title link))
                    link)))
    (fuel-markup--insert-button label link type)))

(defun fuel-markup--links (e)
  (dolist (link (cdr e))
    (fuel-markup--link (list '$link link))
    (insert ", "))
  (delete-backward-char 2))

(defun fuel-markup--index-quotation (q)
  (cond ((null q) null)
        ((listp q) (vconcat (mapcar 'fuel-markup--index-quotation q)))
        (t q)))

(defun fuel-markup--index (e)
  (let* ((q (fuel-markup--index-quotation (cadr e)))
         (cmd `(:fuel* ((,q fuel-index)) "fuel"
                       ("builtins" "help" "help.topics" "classes"
                        "classes.builtin" "classes.tuple"
                        "classes.singleton" "classes.union"
                        "classes.intersection" "classes.predicate")))
         (subs (fuel-eval--retort-result (fuel-eval--send/wait cmd 200))))
    (when subs
      (let ((start (point))
            (sort-fold-case nil))
        (fuel-markup--print subs)
        (sort-lines nil start (point))))))

(defun fuel-markup--vocab-link (e)
  (fuel-markup--insert-button (cadr e) (cadr e) 'vocab))

(defun fuel-markup--vocab-links (e)
  (dolist (link (cdr e))
    (insert " ")
    (fuel-markup--vocab-link (list '$vocab-link link))
    (insert " ")))

(defun fuel-markup--vocab-list (e)
  (let ((rows (mapcar '(lambda (elem)
                         (list (list '$vocab-link (car elem)) (cadr elem)))
                      (cdr e))))
    (fuel-markup--table (cons '$table rows))))

(defun fuel-markup--describe-vocab (e)
  (fuel-markup--insert-nl-if-nb)
  (let* ((cmd `(:fuel* ((,(cadr e) fuel-vocab-help)) "fuel" t))
         (res (fuel-eval--retort-result (fuel-eval--send/wait cmd))))
    (when res (fuel-markup--print res))))

(defun fuel-markup--vocabulary (e)
  (fuel-markup--insert-heading "Vocabulary: " t)
  (fuel-markup--vocab-link (cons '$vocab-link (cdr e)))
  (newline))

(defun fuel-markup--list (e)
  (fuel-markup--insert-nl-if-nb)
  (dolist (elt (cdr e))
    (insert " - ")
    (fuel-markup--print elt)
    (fuel-markup--insert-newline)))

(defun fuel-markup--table (e)
  (fuel-markup--insert-newline)
  (delete-blank-lines)
  (newline)
  (let* ((table-time-before-update 0)
         (table-time-before-reformat 0)
         (start (point))
         (col-delim "<~end-of-col~>")
         (col-no (length (cadr e)))
         (width (/ (- (window-width) 10) col-no))
         (step 100)
         (count 0)
         (inst '(lambda ()
                  (table-capture start (point) col-delim nil nil width col-no)
                  (goto-char (point-max))
                  (table-recognize -1)
                  (newline)
                  (setq start (point)))))
    (dolist (row (cdr e))
      (dolist (col row)
        (fuel-markup--print col)
        (insert col-delim)
        (setq count (1+ count))
        (when (zerop (mod count step)) (funcall inst))))
    (unless (zerop (mod count step)) (funcall inst))))

(defun fuel-markup--instance (e)
  (insert " an instance of ")
  (fuel-markup--print (cadr e)))

(defun fuel-markup--maybe (e)
  (fuel-markup--instance (cons '$instance (cdr e)))
  (insert " or f "))

(defun fuel-markup--values (e)
  (fuel-markup--insert-heading "Inputs and outputs")
  (dolist (val (cdr e))
    (insert " " (car val) " - ")
    (fuel-markup--print (cdr val))
    (newline)))

(defun fuel-markup--predicate (e)
  (fuel-markup--values '($values ("object" object) ("?" "a boolean")))
  (let ((word (make-symbol (substring (format "%s" (cadr e)) 0 -1))))
  (fuel-markup--description
   `($description "Tests if the object is an instance of the "
                  ($link ,word) " class."))))

(defun fuel-markup--side-effects (e)
  (fuel-markup--insert-heading "Side effects")
  (insert "Modifies ")
  (fuel-markup--print (cdr e))
  (fuel-markup--insert-newline))

(defun fuel-markup--definition (e)
  (fuel-markup--insert-heading "Definition")
  (fuel-markup--code (cons '$code (cdr e))))

(defun fuel-markup--methods (e)
  (fuel-markup--insert-heading "Methods")
  (fuel-markup--code (cons '$code (cdr e))))

(defun fuel-markup--value (e)
  (fuel-markup--insert-heading "Variable value")
  (insert "Current value in global namespace: ")
  (fuel-markup--snippet (cons '$snippet (cdr e)))
  (newline))

(defun fuel-markup--values-x/y (e)
  (fuel-markup--values '($values ("x" "number") ("y" "number"))))

(defun fuel-markup--curious (e)
  (fuel-markup--insert-heading "For the curious...")
  (fuel-markup--print (cdr e)))

(defun fuel-markup--references (e)
  (fuel-markup--insert-heading "References")
  (dolist (ref (cdr e))
    (if (listp ref)
        (fuel-markup--print ref)
      (fuel-markup--subsection (list '$subsection ref)))))

(defun fuel-markup--see-also (e)
  (fuel-markup--insert-heading "See also")
  (fuel-markup--links (cons '$links (cdr e))))

(defun fuel-markup--related (e)
  (fuel-markup--insert-heading "See also")
  (fuel-markup--links (cons '$links (cadr e))))

(defun fuel-markup--shuffle (e)
  (insert "\nShuffle word. Re-arranges the stack "
          "according to the stack effect pattern.")
  (fuel-markup--insert-newline))

(defun fuel-markup--low-level-note (e)
  (fuel-markup--print '($notes "Calling this word directly is not necessary "
                               "in most cases. "
                               "Higher-level words call it automatically.")))

(defun fuel-markup--parsing-note (e)
  (fuel-markup--insert-nl-if-nb)
  (insert "This word should only be called from parsing words.")
  (fuel-markup--insert-newline))

(defun fuel-markup--io-error (e)
  (fuel-markup--errors '($errors "Throws an error if the I/O operation fails.")))

(defun fuel-markup--prettyprinting-note (e)
  (fuel-markup--print '($notes ("This word should only be called within the "
                                ($link with-pprint) " combinator."))))

(defun fuel-markup--elem-with-heading (elem heading)
  (fuel-markup--insert-heading heading)
  (fuel-markup--print (cdr elem))
  (fuel-markup--insert-newline))

(defun fuel-markup--quotation (e)
  (insert "a ")
  (fuel-markup--link (list '$link 'quotation 'quotation 'word))
  (insert " with stack effect ")
  (fuel-markup--snippet (list '$snippet (nth 1 e))))

(defun fuel-markup--warning (e)
  (fuel-markup--elem-with-heading e "Warning"))

(defun fuel-markup--description (e)
  (fuel-markup--elem-with-heading e "Word description"))

(defun fuel-markup--class-description (e)
  (fuel-markup--elem-with-heading e "Class description"))

(defun fuel-markup--error-description (e)
  (fuel-markup--elem-with-heading e "Error description"))

(defun fuel-markup--var-description (e)
  (fuel-markup--elem-with-heading e "Variable description"))

(defun fuel-markup--contract (e)
  (fuel-markup--elem-with-heading e "Generic word contract"))

(defun fuel-markup--errors (e)
  (fuel-markup--elem-with-heading e "Errors"))

(defun fuel-markup--examples (e)
  (fuel-markup--elem-with-heading e "Examples"))

(defun fuel-markup--notes (e)
  (fuel-markup--elem-with-heading e "Notes"))

(defun fuel-markup--see (e)
  (let* ((word (nth 1 e))
         (cmd (and word `(:fuel* (,(format "%s" word) fuel-word-see) "fuel" t)))
         (res (and cmd
                   (fuel-eval--retort-result (fuel-eval--send/wait cmd 100)))))
    (if res
        (fuel-markup--code (list '$code res))
      (fuel-markup--snippet (list '$snippet word)))))

(defun fuel-markup--synopsis (e)
  (insert (format " %S " e)))


(provide 'fuel-markup)
;;; fuel-markup.el ends here

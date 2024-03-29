;;; fuel-log.el -- logging utilities -*- lexical-binding: t -*-

;; Copyright (C) 2008, 2009 Jose Antonio Ortega Ruiz
;; See https://factorcode.org/license.txt for BSD license.

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Keywords: languages, fuel, factor
;; Start date: Sun Dec 14, 2008 01:00

;;; Comentary:

;; Some utilities for maintaining a simple log buffer, mainly for
;; debugging purposes.

;;; Code:

(require 'fuel-base)

;;; Customization:

(defvar fuel-log--buffer-name "*fuel messages*"
  "Name of the log buffer")

(defvar fuel-log--max-buffer-size 128000
  "Maximum size of the Factor messages log")

(defvar fuel-log--max-message-size 1024
  "Maximum size of individual log messages")

(defvar fuel-log--verbose-p t
  "Log level for Factor messages")

(defvar fuel-log--inhibit-p nil
  "Set this to t to inhibit all log messages")

(defvar fuel-log--debug-p nil
  "If t, all messages are logged no matter what")

;;;###autoload
(define-derived-mode factor-messages-mode fundamental-mode "FUEL Messages"
  "Simple mode to log interactions with the factor listener"
  (buffer-disable-undo)
  (setq-local comint-redirect-subvert-readonly t)
  (add-hook 'after-change-functions
            #'(lambda (b e len)
               (let ((inhibit-read-only t))
                 (when (> b fuel-log--max-buffer-size)
                   (delete-region (point-min) b))))
            nil t))

(defun fuel-log--buffer ()
  (or (get-buffer fuel-log--buffer-name)
      (with-current-buffer (get-buffer-create fuel-log--buffer-name)
        (factor-messages-mode)
        (current-buffer))))

(defun fuel-log--timestamp ()
  (format-time-string "%Y-%m-%d %T"))

(defun fuel-log--format-msg (type args)
  (format "%s %s: %s\n\n" (fuel-log--timestamp) type (apply 'format args)))

(defun fuel-log--msg (type args)
  (when (or fuel-log--debug-p (not fuel-log--inhibit-p))
    (with-current-buffer (fuel-log--buffer)
      (goto-char (point-max))
      (let ((inhibit-read-only t))
        (insert
         (fuel-shorten-str (fuel-log--format-msg type args)
                           fuel-log--max-message-size))))))

(defun fuel-log--warn (&rest args)
  (fuel-log--msg 'WARNING args))

(defun fuel-log--error (&rest args)
  (fuel-log--msg 'ERROR args))

(defun fuel-log--info (&rest args)
  (when fuel-log--verbose-p
    (fuel-log--msg 'INFO args)))

(provide 'fuel-log)

;;; fuel-log.el ends here

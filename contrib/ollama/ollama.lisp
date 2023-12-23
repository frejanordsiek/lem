(defpackage #:lem-ollama 
  (:use :cl :lem :alexandria)
  (:export #:*host* 
           #:*model* 
           #:*ollama-mode-keymap*
           #:ollama-mode
           #:ollama-prompt 
           #:ollama-request 
           #:handle-stream))
(in-package :lem-ollama)

(defparameter *host* "192.168.68.110:11434")
(defparameter *model* "mistral")
(defparameter *resp* nil)

(define-major-mode ollama-mode nil 
    (:name "ollama"
     :keymap *ollama-mode-keymap*))
(define-key *ollama-mode-keymap* "C-c C-c" 'ollama-cancel)

(define-command ollama-cancel () ()
  (unless (null *resp*)
    (close *resp*)
    (setf *resp* nil)))

(defun chunga-read-line (stream)
  "chunga:read-line* doesnt work, so use this."
  (loop :with line := ""
        :for c := (chunga:read-char* stream)
        :while (not (eql c #\newline))
        :do (setf line (concatenate 'string line (string c)))
        :finally (return line)))

(defun handle-stream (output)
  (loop :for line := (chunga-read-line *resp*)
        :for data := (cl-json:decode-json-from-string line)
        :while (not (assoc-value data :done))
        :do (format output (assoc-value data :response))
        :do (redraw-display)))

(defun ollama-request (prompt)
  (setf *resp*
        (dex:post
         (format nil "http://~a/api/generate" *host*)
         :want-stream t
         :force-binary t
         :keep-alive nil
         :read-timeout 120
         :headers '(("content-type" . "application/json"))
         :content (cl-json:encode-json-to-string
                   `(("model" . ,*model*)
                     ("prompt" . ,prompt))))))

(define-command ollama-prompt (prompt) ("sPrompt: ")
  (let ((buf (make-buffer "*ollama*" :temporary t)))
    (unless (eq (buffer-major-mode buf) 'ollama-mode)
      (change-buffer-mode buf 'ollama-mode))
    (pop-to-buffer buf)
    (bt2:make-thread 
     (lambda () 
       (ollama-request prompt)
       (with-open-stream (out (make-buffer-output-stream (buffer-point buf)))
         (handle-stream out))))))

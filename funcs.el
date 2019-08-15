;;; Copyright (C) 2018, 2019 Andreas Fuchs <asf@boinkor.net>
;;; Made available to you under the terms of GPLv2 or later: https://choosealicense.com/licenses/gpl-2.0/

;;; https://gist.github.com/antifuchs/aa9fa4c3d1354ea163bc13e63d32db1a

(defconst asf--rustdoc-line-prefixes (concat "^\\([\t ]*" (regexp-opt '("///" "//!")) "\\)"))

(defun asf--rustdoc-current-comment-block-region ()
  (save-excursion
    (forward-line 0)
    (when (looking-at asf--rustdoc-line-prefixes)
      ;; determine the current line's prefix & extract all the lines
      ;; with matching prefixes that surround it (we assume that's the
      ;; extent of the rustdoc block):
      (let ((prefix (match-string-no-properties 1))
            (initial-position (point))
            start end)
        ;; look back:
        (while (and (looking-at prefix)
                    (not (eql (point) (point-min))))
          (setq start (point))
          (forward-line -1))
        (when (looking-at prefix)
          ;; we're at the beginning of the buffer; make sure we got that:
          (setq start (point)))
        (goto-char initial-position)
        (while (and (not (eql (point) (point-max)))
                    (looking-at prefix))
          (forward-line 1)
          (setq end (point)))
        (list start end)))))

(defvar asf--rustdoc-prefix)

(defun asf--rustdoc-prefix-without-space (prefix)
  (replace-regexp-in-string "[\t ]*$" "" prefix))

(defun asf--rustdoc-strip-prefix ()
  (save-excursion
    (goto-char (point-min))
    ;; infer prefix from first line:
    (let* ((prefix (when (looking-at (concat asf--rustdoc-line-prefixes "[\t ]*"))
                     (match-string 0)))
           (prefix-re (concat "^" prefix))
           (empty-line-prefix-re (concat "^" (asf--rustdoc-prefix-without-space prefix))))
      (while (< (point) (point-max))
        (when (or (looking-at prefix-re)
                  (looking-at empty-line-prefix-re))
          (replace-match "")
          (forward-line 1)))
      prefix)))

(defun asf--rustdoc-apply-prefix ()
  (let ((prefix asf--rustdoc-prefix))
    (save-excursion
      (goto-char (point-min))
      (while (and (re-search-forward "^" nil t)
                  (not (eql (point) (point-max))))
        (replace-match prefix 't))
      (whitespace-cleanup)
      (goto-char (point-max))
      ;; non-empty lines at the end must end in a newline:
      (unless (looking-at "^$")
        (insert "\n")))))

(defun asf--rustdoc-setup-buffer ()
  ;; Strip the comment prefix from lines & set up the buffer's major mode:
  (let ((prefix (asf--rustdoc-strip-prefix)))
    (markdown-mode)

    (setq-local asf--rustdoc-prefix prefix)
    (setq-local edit-indirect-before-commit-hook '(asf--rustdoc-apply-prefix))))

(defun asf-rustdoc-edit ()
  (interactive)
  (let ((guess (asf--rustdoc-current-comment-block-region)))
    (unless guess
      (error "Not in a rustdoc comment that I can guess!"))
    (destructuring-bind (start end) guess
      (let ((edit-indirect-after-creation-hook 'asf--rustdoc-setup-buffer))
        (edit-indirect-region start end t)))))

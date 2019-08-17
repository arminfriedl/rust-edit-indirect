;;; -*- lexical-binding: t -*-

;;; MIT License
;;;
;;; Copyright (c) 2019 Armin Friedl <armin.friedl@outlook.com>
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy
;;; of this software and associated documentation files (the "Software"), to deal
;;; in the Software without restriction, including without limitation the rights
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;;; copies of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.

;;; These functions determine the block of rust comment `point' is currently at
;;; and set up an `edit-indirect' buffer for convenient editing and proper markdown
;;; syntax highlighting.
;;;
;;; Inspired by antifuch's `asf-rustdoc-edit' [1], this is a complete rewrite.
;;; [1] https://gist.github.com/antifuchs/aa9fa4c3d1354ea163bc13e63d32db1a

(require 'dash)

;; Start editing a rust comment in edit-indirect mode
;;
;; This is the only user facing function of rust-edit-indirect
(defun rust-edit-indirect ()
  (interactive)
  (-let [matching-comment (rei--matching-comment-property)]
    (if matching-comment
        (rei--start-edit-indirect matching-comment)
      (error "Couldn't find comment. If you are in a comment, please file a bug report"))))

;; Regex for matching comments
;; ===========================
;;
;; The first match group always denotes the used comment syntax:
;; * //  ... for inner line comments
;; * //! ... for inner line doc comments
;; * /// ... for outer line doc comments
;;
;; The second match group always denotes the space before the comment start.
;;
;; Currently only line comments are handled, no block comments.
;;
(setq rei-outer-line-doc-rx (rx (group-n 2 bol (* blank))            ; any space at the beginning
                                (group-n 1 "///")                    ; the outer line doc marker
                                (not (in "/"))))                     ; not another '/' which would
                                                                     ; mark a regular line comment

(setq rei-inner-line-doc-rx (rx (group-n 2 bol (* blank))            ; any space at the beginning
                                (group-n 1 "//!")))                  ; the inner line doc marker

(setq rei-inner-line-comment-rx (rx (group-n 2 bol (* blank))        ; any space at the beginning
                                    (group-n 1 "//")                 ; the inner line marker
                                    (or (not (in "/!")) "//")))      ; no '!' or single '/' which
                                                                     ; would mark an outer/inner-line-doc,
                                                                     ; another _pair_ of '//' allowed though

(setq rei-comment-plist `((:key rei-outer-line-doc :regex ,rei-outer-line-doc-rx :prefix "///")
                          (:key rei-inner-line-doc :regex ,rei-inner-line-doc-rx :prefix "//!")
                          (:key rei-inner-line-comment :regex ,rei-inner-line-comment-rx :prefix "//")))

(defun rei--start-edit-indirect (matching-comment)
  "Get the comment block, set up edit-indirect buffer and open"
  (-let ((prefix (plist-get matching-comment :prefix))
         ((comment-start comment-end) (rei--comment-block-region matching-comment))
         (edit-indirect-after-creation-hook #'rei--setup-buffer))

    (edit-indirect-region comment-start comment-end 't)))

(defun rei--setup-buffer ()
  "Set up the `edit-indirect' buffer
WARNING: This is a closure over a prefix! Do not use this as regular function

* Set major mode to `markdown-mode'
* Strip comment prefix"

  (markdown-mode)
  (save-excursion 
    ;; strip prefix
    (goto-char (point-min))
    (while (re-search-forward (concat prefix (rx (* blank))) 'nil 't)
      (replace-match ""))
    (setq-local prefix prefix)
    (setq-local edit-indirect-before-commit-hook #'rei--teardown-buffer)))

(defun rei--teardown-buffer ()
  "Tear down the `edit-indirect' buffer
WARNING: This is a closure over a prefix! Do not use this as regular function

* Add comment prefix
* Clean up white space"

  (goto-char (point-min))
  (while (< (point) (point-max))
    (insert prefix " ")
    (forward-line 1))

  ;; If the last line is empty, we need to `(insert prefix)' one last time
  (when (looking-at-p (rx bol))
    (insert prefix))

  ;; Remove trailing whitespace for empty comment lines
  (whitespace-cleanup))

(defun rei--comment-block-region (matching-comment)
  "Determine the region of the comment"
  (assert matching-comment)

  (save-excursion
    (forward-line 0)

    (-let (((&plist :key :regex :prefix) matching-comment)
           (comment-start)
           (comment-end))

      ; walk up until regex doesn't match, or at beginning of buffer
      (while (and (looking-at-p regex) (eq (forward-line -1) 0)))
      ; set comment region start
      (if (and (eq (point) (point-min)) (looking-at-p regex))
          ; handle beginning-of-buffer special case
          (setq comment-start (point-at-bol))
        (forward-line 1) ; we went one line too far
        (setq comment-start (point-at-bol)))

      ; walk down until regex doesn't match, or at end of buffer
      (while (and (looking-at-p regex) (eql (forward-line 1) 0)))
      ; set comment region end
      (if (and (eq (point) (point-max)) (looking-at-p regex))
          ; handle end-of-buffer special case
          (setq comment-end (point-at-bol))
        (forward-line -1) ; we went one line too far
        (setq comment-end (point-at-eol)))

      ; return result
      (list comment-start comment-end))))

(defun rei--matching-comment-property ()
  "Return the property from `rei-comment-plist' for the comment form of the current line"
  (save-excursion
    (forward-line 0)
    (-first (-lambda ((&plist :regex regex)) (looking-at-p regex))
            rei-comment-plist)))

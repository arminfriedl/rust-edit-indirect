;;; packages.el --- rust-edit-indirect layer packages file for Spacemacs.
;;
;; Copyright (c) 2012-2018 Sylvain Benner & Contributors
;;
;; Author: Armin Friedl <armin@DESKTOP-VTON8JS>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:

;; See the Spacemacs documentation and FAQs for instructions on how to implement
;; a new layer:
;;
;;   SPC h SPC layers RET
;;
;;
;; Briefly, each package to be installed or configured by this layer should be
;; added to `rust-edit-indirect-packages'. Then, for each package PACKAGE:
;;
;; - If PACKAGE is not referenced by any other Spacemacs layer, define a
;;   function `rust-edit-indirect/init-PACKAGE' to load and initialize the package.

;; - Otherwise, PACKAGE is already referenced by another Spacemacs layer, so
;;   define the functions `rust-edit-indirect/pre-init-PACKAGE' and/or
;;   `rust-edit-indirect/post-init-PACKAGE' to customize the package as it is loaded.

;;; Code:

(defconst rust-edit-indirect-packages
  '(edit-indirect rust-mode)
  "The list of Lisp packages required by the rust-edit-indirect layer.

Each entry is either:

1. A symbol, which is interpreted as a package to be installed, or

2. A list of the form (PACKAGE KEYS...), where PACKAGE is the
    name of the package to be installed or loaded, and KEYS are
    any number of keyword-value-pairs.

    The following keys are accepted:

    - :excluded (t or nil): Prevent the package from being loaded
      if value is non-nil

    - :location: Specify a custom installation location.
      The following values are legal:

      - The symbol `elpa' (default) means PACKAGE will be
        installed using the Emacs package manager.

      - The symbol `local' directs Spacemacs to load the file at
        `./local/PACKAGE/PACKAGE.el'

      - A list beginning with the symbol `recipe' is a melpa
        recipe.  See: https://github.com/milkypostman/melpa#recipe-format")

(defun rust-edit-indirect/init-edit-indirect ()
  (use-package edit-indirect
    :defer t
    :init
    ;; edit-indirect uses a special approach to prevent edit-indirect-mode from being called interactively.
    ;; edit-indirect--overlay is the minor mode used for edit-indirect buffers
    (progn (spacemacs/set-leader-keys-for-minor-mode 'edit-indirect--overlay "''" 'edit-indirect-commit)
           (spacemacs/set-leader-keys-for-minor-mode 'edit-indirect--overlay "'c" 'edit-indirect-abort))))

(defun rust-edit-indirect/post-init-rust-mode ()
  (spacemacs/set-leader-keys-for-major-mode 'rust-mode "''" 'asf-rustdoc-edit))

;;; packages.el ends here

;;; elisp-slime-expand.el --- A SLIME inspired expander for macros.

;; Copyright (C) 2012  Russell Sim

;; Author: Russell Sim <russell.sim@gmail.com>
;; Keywords: lisp, convenience, tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This mode provides a similar exprience to the SLIME macroexpand
;; functions in `emacs-lisp-mode'.

;;; Code:

(defvar elisp-slime-expand-mode-map (make-sparse-keymap))

(define-key elisp-slime-expand-mode-map "\C-c\C-m"
  'macroexpand-at-point)

(define-key elisp-slime-expand-mode-map "\C-c\M-m"
  'macroexpand-all-at-point)


(define-minor-mode elisp-slime-expand-mode
  "Enable SLIME like macroexpand.

Commands:
\\{elisp-slime-expand-mode-map}"
  nil " SliExp" elisp-slime-expand-mode-map)

(defconst macroexpand-buffer "*Macroexpand*"
  "The expanded form of an sexp.")

(defvar eval-macroexpand-expression nil
  "Specifies the last macroexpansion performed. This variable
  specifies both what was expanded and how.")

(defun macroexpand-to-string (sexp &optional expand-func)
  "Expand an `sexp' using the `expand-func' function and return
it as a string."
  (replace-regexp-in-string
   "\\`[ \t\n]*" ""
   (replace-regexp-in-string
    "[ \t\n]*\\'" ""
    (with-output-to-string
      (with-temp-buffer
        (insert "(")
        (insert (if expand-func (symbol-name expand-func) "cl-macroexpand"))
        (insert " (quote ")
        (insert sexp)
        (insert "))")
        (eval-buffer nil standard-output))))))

(defun elisp-macroexpand-at-point-1 (&optional expand-func)
  (save-excursion
    (let ((cpoint (point))
          (apoint (if (equal (char-to-string (char-after)) "(")
                      (point) (search-backward "(" nil t)))
          (epoint (progn (forward-sexp) (point)))
          (expand-func (if expand-func
                           expand-func
                         'cl-macroexpand)))
      (goto-char cpoint)
      (let ((expression (buffer-substring-no-properties apoint epoint)))
        (when (get-buffer macroexpand-buffer)
          (kill-buffer macroexpand-buffer))
        (switch-to-buffer macroexpand-buffer)
        (when (get-buffer macroexpand-buffer)
          (insert (macroexpand-to-string expression expand-func))
          (goto-char (point-max))
          ;; Sometimes prettyprinting doesn't work because of line
          ;; breaks function documentation :( this solution isn't the
          ;; best because string formatting isn't preserved.
          ;; (while (not (eq (line-number-at-pos) 1))
          ;;   (join-line))
          (set-buffer macroexpand-buffer)
          (emacs-lisp-mode)
          (goto-char (point-min))
          (delete-region (point) (1- (search-forward "(" nil t)))
          (goto-char (point-min))
          (cl--do-prettyprint)
          (setq buffer-read-only t)
          (goto-char (point-min))
          (elisp-macroexpansion-minor-mode 1)
          (setq eval-macroexpand-expression `(,expand-func ,expression)))))))

(defun macroexpand-all-at-point ()
  "Expand the all macros in the current sexp at point and display
it in a separate buffer."
  (interactive)
  (elisp-macroexpand-at-point-1 'macroexpand-all))

(defun macroexpand-at-point ()
  "Expand the current sexp at point and display it in a separate
buffer."
  (interactive)
  (elisp-macroexpand-at-point-1))

(defun elisp-slime-expand-inline-at-point ()
  "Expand the current sexp if it's a macro and pretty print it."
  (interactive)
  (setq buffer-read-only nil)
  (let ((cpoint (point))
        (apoint (if (equal (char-to-string (char-after)) "(")
                    (point) (search-backward "(" nil t)))
        (epoint (progn (forward-sexp) (point))))
    (let ((expression (buffer-substring-no-properties apoint epoint)))
      (delete-region apoint epoint)
      (goto-char apoint)
      (insert (macroexpand-to-string expression))
      (goto-char apoint))
    (cl--do-prettyprint)
    (goto-char apoint)
    (setq buffer-read-only t)))

(defun elisp-slime-expand-macro-again ()
  "Refresh the display of the current macro."
  (interactive)
  (let ((cpoint (point)))
    (when (get-buffer macroexpand-buffer)
      (setq buffer-read-only nil)
      (delete-region (point-min) (point-max))
      (insert (macroexpand-to-string (cadr eval-macroexpand-expression)
                                     (car eval-macroexpand-expression)))
      (goto-char (point-min))
      (delete-region (point) (1- (search-forward "(" nil t)))
      (goto-char (point-min))
      (cl--do-prettyprint)
      (setq buffer-read-only t)
      (goto-char cpoint))))

(defvar elisp-slime-expand-minor-mode-map (make-sparse-keymap))

(define-key elisp-slime-expand-minor-mode-map "g" 'elisp-slime-expand-macro-again)
(define-key elisp-slime-expand-minor-mode-map "\C-c\C-m" 'elisp-slime-expand-inline-at-point)
(define-key elisp-slime-expand-minor-mode-map "q" 'bury-buffer)

(define-minor-mode elisp-macroexpansion-minor-mode
  "elisp mode for macroexpansion

Commands:
\\{elisp-slime-expand-minor-mode-map}"
  nil
  " Macroexpand"
  '(("g" . eslisp-slime-expand-macro-again)
    ("\C-c\C-m" . eslisp-slime-expand-inline-at-point)
    ("q" . bury-buffer))
  (make-variable-buffer-local 'eval-macroexpand-expression))

(provide 'elisp-slime-expand)
;;; elisp-slime-expand.el ends here

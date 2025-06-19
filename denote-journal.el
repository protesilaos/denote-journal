;;; denote-journal.el --- Convenience functions for daily journaling with Denote -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2025  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://github.com/protesilaos/denote-journal
;; Version: 0.1.1
;; Package-Requires: ((emacs "28.1") (denote "4.0.0"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a set of optional convenience functions that used to be
;; provided in the Denote manual.  They facilitate the use of Denote
;; for daily journaling.

;;; Code:

(require 'denote)
(require 'calendar)
(eval-when-compile (require 'cl-lib))

(defgroup denote-journal nil
  "Convenience functions for daily journaling with Denote."
  :group 'denote
  :link '(info-link "(denote) Top")
  :link '(info-link "(denote-journal) Top")
  :link '(url-link :tag "Denote homepage" "https://protesilaos.com/emacs/denote")
  :link '(url-link :tag "Denote Journal homepage" "https://protesilaos.com/emacs/denote-journal"))

(defcustom denote-journal-directory
  (expand-file-name "journal" denote-directory)
  "Directory for storing daily journal entries.
This can either be the same as the variable `denote-directory' or
a subdirectory of it.

A value of nil means to use the variable `denote-directory'.
Journal entries will thus be in a flat listing together with all
other notes.  They can still be retrieved easily by searching for
the variable `denote-journal-keyword'."
  :group 'denote-journal
  :type '(choice (directory :tag "Provide directory path (is created if missing)")
                 (const :tag "Use the `denote-directory'" nil)))

(defcustom denote-journal-keyword "journal"
  "Single word keyword or list of keywords to tag journal entries.
It is used by `denote-journal-new-entry' (or related)."
  :group 'denote-journal
  :type '(choice (string :tag "Keyword")
                 (repeat :tag "List of keywords" string)))

(defcustom denote-journal-title-format 'day-date-month-year-24h
  "Date format to construct the title with `denote-journal-new-entry'.
The value it can take is either nil, a
custom string, or a symbol:

- When `denote-journal-title-format' is set to a nil value, then new
  journal entries always prompt for a title.  Users will want this if
  they prefer to journal using a given theme for the day rather than
  the date itself (e.g. instead of \"1st of April 2025\" they may prefer
  something like \"Early Spring at the hut\").

- When `denote-journal-title-format' is set to an empty or blank
  string (string with only spaces), then new journal entries will not
  use a file title.

- When `denote-journal-title-format' is set to a symbol, it is one
  among `day' (results in a title like \"Tuesday\"), `day-date-month-year'
  (for a result like \"Tuesday 1 April 2025\"), `day-date-month-year-24h'
  (for \"Tuesday 1 April 2025 13:46\"), or `day-date-month-year-12h'
  (e.g. \"Tuesday 1 April 2025 02:46 PM\").

- When `denote-journal-title-format' is set to a string, it is used
  literally except for any \"format specifiers\", as interpreted by the
  function `format-time-string', which are replaced by their given
  date component.  For example, the `\"Week %V on %A %e %B %Y at %H:%M\"''
  will yield a title like \"Week 14 on 1 April 2025 at 13:48\"."
  :group 'denote-journal
  :type '(choice
          (const :tag "Prompt for title with `denote-journal-new-entry'" nil)
          (const :tag "Monday"
                 :doc "The `format-time-string' is: %A"
                 day)
          (const :tag "Monday 19 September 2023"
                 :doc "The `format-time-string' is: %A %e %B %Y"
                 day-date-month-year)
          (const :tag "Monday 19 September 2023 20:49"
                 :doc "The `format-time-string' is: %A %e %B %Y %H:%M"
                 day-date-month-year-24h)
          (const :tag "Monday 19 September 2023 08:49 PM"
                 :doc "The `format-time-string' is: %A %e %B %Y %I:%M %^p"
                 day-date-month-year-12h)
          (string :tag "Custom string with `format-time-string' specifiers")))

(defcustom denote-journal-hook nil
  "Normal hook called after `denote-journal-new-entry'.
Use this to, for example, set a timer after starting a new
journal entry (refer to the `tmr' package on GNU ELPA)."
  :group 'denote-journal
  :type 'hook)

(defun denote-journal-directory ()
  "Make the variable `denote-journal-directory' and its parents."
  (if-let* (((stringp denote-journal-directory))
            (directory (file-name-as-directory (expand-file-name denote-journal-directory))))
      (progn
        (when (not (file-directory-p denote-journal-directory))
          (make-directory directory :parents))
        directory)
    (denote-directory)))

(defun denote-journal-keyword ()
  "Return the value of the variable `denote-journal-keyword' as a list."
  (if (stringp denote-journal-keyword)
      (list denote-journal-keyword)
    denote-journal-keyword))

(defun denote-journal--keyword-regex ()
  "Return a regular expression string that matches the journal keyword(s)."
  (let ((keywords-sorted (mapcar #'regexp-quote (denote-keywords-sort (denote-journal-keyword)))))
    (concat "_" (string-join keywords-sorted ".*_"))))

(defun denote-journal-file-is-journal-p (file)
  "Return non-nil if FILE is a journal entry."
  (and (denote-file-is-note-p file)
       (string-match-p (denote-journal--keyword-regex) (file-name-nondirectory file))))

(defun denote-journal-filename-is-journal-p (filename)
  "Return non-nil if FILENAME is a valid name for a journal entry."
  (and (denote-filename-is-note-p filename)
       (string-match-p (denote-journal--keyword-regex) (file-name-nondirectory filename))))

(defun denote-journal-daily--title-format (&optional date)
  "Return appropriate value for `denote-journal-title-format'.
With optional DATE, use it instead of the present date wherever
relevant.  DATE has the same format as that returned by `current-time'."
  (let ((specifiers (pcase denote-journal-title-format
                      ((pred null)
                       (cons
                        (denote-title-prompt (format-time-string "%F" date) "New journal file TITLE")
                        :skip))
                      ((and (pred stringp) (pred string-blank-p))
                       (cons "" :skip))
                      ((pred stringp) denote-journal-title-format)
                      ('day "%A")
                      ('day-date-month-year "%A %e %B %Y")
                      ('day-date-month-year-24h "%A %e %B %Y %H:%M")
                      ('day-date-month-year-12h "%A %e %B %Y %I:%M %^p"))))
    (if (consp specifiers)
        (car specifiers)
      (format-time-string specifiers date))))

(defun denote-journal--get-template ()
  "Return template that has `journal' key in `denote-templates'.
If no template with `journal' key exists but `denote-templates'
is non-nil, prompt the user for a template among
`denote-templates'.  Else return nil."
  ;; FIXME 2025-04-02: Here we assume that `denote-templates' is an
  ;; alist.  Maybe we need to be more careful.
  (when denote-templates
    (or (alist-get 'journal denote-templates)
        (denote-template-prompt))))

;;;###autoload
(defun denote-journal-new-entry (&optional date)
  "Create a new journal entry in variable `denote-journal-directory'.
Use the variable `denote-journal-keyword' as a keyword for the
newly created file.  Set the title of the new entry according to the
value of the user option `denote-journal-title-format'.

With optional DATE as a prefix argument, prompt for a date.  If
`denote-date-prompt-use-org-read-date' is non-nil, use the Org
date selection module.

When called from Lisp DATE is a string and has the same format as
that covered in the documentation of the `denote' function.  It
is internally processed by `denote-valid-date-p'."
  (interactive (list (when current-prefix-arg (denote-date-prompt))))
  (let ((internal-date (or (denote-valid-date-p date) (current-time)))
        (denote-directory (denote-journal-directory)))
    (denote
     (denote-journal-daily--title-format internal-date)
     (denote-journal-keyword)
     nil nil date
     (denote-journal--get-template))
    (run-hooks 'denote-journal-hook)))

(defun denote-journal--filename-date-regexp (&optional date)
  "Regular expression to match journal entries for today or optional DATE.
DATE has the same format as that returned by `denote-valid-date-p'."
  (let* ((identifier (format "%sT[0-9]\\{6\\}" (format-time-string "%Y%m%d" date)))
         (order denote-file-name-components-order)
         (id-index (seq-position order 'identifier))
         (kw-index (seq-position order 'keywords)))
    (if (> kw-index id-index)
        (format "%s.*?%s" identifier (denote-journal--keyword-regex))
      (format "%s.*?@@%s" (denote-journal--keyword-regex) identifier))))

(defun denote-journal--entry-today (&optional date)
  "Return list of files matching a journal for today or optional DATE.
DATE has the same format as that returned by `denote-valid-date-p'."
  (let ((denote-directory (denote-journal-directory)))
    (denote-directory-files (denote-journal--filename-date-regexp date))))

(defun denote-journal-select-file-prompt (files)
  "Prompt for file among FILES if >1, else return the `car'.
Perform the operation relative to the variable `denote-journal-directory'."
  (let* ((default-directory (denote-journal-directory))
         (denote-directory default-directory)
         (relative-files (mapcar #'denote-get-file-name-relative-to-denote-directory files))
         (file (if (> (length files) 1)
                   (completing-read "Select journal entry: " (denote--completion-table 'file relative-files) nil t)
                 (car relative-files))))
    (concat denote-directory file)))

;;;###autoload
(defun denote-journal-path-to-new-or-existing-entry (&optional date)
  "Return path to existing or new journal file.
With optional DATE, do it for that date, else do it for today.  DATE is
a string and has the same format as that covered in the documentation of
the `denote' function.  It is internally processed by `denote-valid-date-p'.

If there are multiple journal entries for the date, prompt for one among
them using minibuffer completion.  If there is only one, return it.  If
there is no journal entry, create it."
  (let* ((internal-date (or (denote-valid-date-p date) (current-time)))
         (files (denote-journal--entry-today internal-date)))
    (if files
        (denote-journal-select-file-prompt files)
      (save-window-excursion
        (denote-journal-new-entry date)
        (save-buffer)
        (buffer-file-name)))))

;;;###autoload
(defun denote-journal-new-or-existing-entry (&optional date)
  "Locate an existing journal entry or create a new one.
A journal entry is one that has the value of the variable
`denote-journal-keyword' as part of its file name.

If there are multiple journal entries for the current date,
prompt for one using minibuffer completion.  If there is only
one, visit it outright.  If there is no journal entry, create one
by calling `denote-journal-new-entry'.

With optional DATE as a prefix argument, prompt for a date.  If
`denote-date-prompt-use-org-read-date' is non-nil, use the Org
date selection module.

When called from Lisp, DATE is a string and has the same format
as that covered in the documentation of the `denote' function.
It is internally processed by `denote-valid-date-p'."
  (interactive
   (list
    (when current-prefix-arg
      (denote-date-prompt))))
  (find-file (denote-journal-path-to-new-or-existing-entry date)))

;;;###autoload
(defun denote-journal-link-or-create-entry (&optional date id-only)
  "Use `denote-link' on journal entry, creating it if necessary.
A journal entry is one that has the value of the variable
`denote-journal-keyword' as part of its file name.

If there are multiple journal entries for the current date,
prompt for one using minibuffer completion.  If there is only
one, link to it outright.  If there is no journal entry, create one
by calling `denote-journal-new-entry' and link to it.

With optional DATE as a prefix argument, prompt for a date.  If
`denote-date-prompt-use-org-read-date' is non-nil, use the Org
date selection module.

When called from Lisp, DATE is a string and has the same format
as that covered in the documentation of the `denote' function.
It is internally processed by `denote-valid-date-p'.

With optional ID-ONLY as a prefix argument create a link that
consists of just the identifier.  Else try to also include the
file's title.  This has the same meaning as in `denote-link'."
  (interactive
   (pcase current-prefix-arg
     ('(16) (list (denote-date-prompt) :id-only))
     ('(4) (list (denote-date-prompt)))))
  (let ((path (denote-journal-path-to-new-or-existing-entry date)))
    (denote-link path
                 (denote-filetype-heuristics (buffer-file-name))
                 (denote-get-link-description path)
                 id-only)))

;;;; Integration with the `calendar'

(defface denote-journal-calendar '((t :box (:line-width (-1 . -1))))
  "Face to mark a Denote journal entry in the `calendar'.")

(defun denote-journal-calendar--file-to-date (file)
  "Convert FILE to calendar date by interpreting its identifier."
  (when-let* ((identifier (denote-retrieve-filename-identifier file))
              (date (denote--id-to-date identifier))
              (numbers (mapcar #'string-to-number (split-string date "-"))))
    (pcase-let ((`(,year ,month ,day) numbers))
      (list month day year))))

(defun denote-journal-calendar--get-files (calendar-date)
  "Return files around CALENDAR-DATE in variable `denote-journal-directory'."
  (pcase-let* ((denote-directory (denote-journal-directory))
               (interval (calendar-interval
                          displayed-month displayed-year ; These are local to the `calendar'
                          (calendar-extract-month calendar-date)
                          (calendar-extract-year calendar-date)))
               (`(,current-month ,_ ,current-year) calendar-date)
               (`(,previous-month . ,previous-year) (calendar-increment-month-cons (- interval 1)))
               (`(,previous-month-2 . ,previous-year-2) (calendar-increment-month-cons (- interval 2)))
               (`(,next-month . ,next-year) (calendar-increment-month-cons (+ interval 1)))
               (`(,next-month-2 . ,next-year-2) (calendar-increment-month-cons (+ interval 2)))
               (years (list previous-year-2 previous-year current-year next-year next-year-2))
               (months (list previous-month-2 previous-month current-month next-month next-month-2))
               (time-regexp (concat (regexp-opt (mapcar #'number-to-string years))
                                    (regexp-opt (mapcar (lambda (number) (format "%02d" number)) months))))
               (keyword-regexp (denote-journal--keyword-regex)))
    (denote-directory-files
     ;; NOTE 2025-03-31: This complex regular expression is to account
     ;; for `denote-file-name-components-order'.  We should probably
     ;; have something in `denote.el' to do this fancy stuff, though
     ;; this is the first time I have a use-case for it.
     (format "\\(%1$s.*%2$s\\)\\|\\(%2$s.*%1$s\\)" time-regexp keyword-regexp))))

(defun denote-journal-calendar-mark-dates ()
  "Mark all visible days in the `calendar' for which there is a Denote journal entry."
  (interactive)
  (when-let* ((date (calendar-cursor-to-date))
              (files (denote-journal-calendar--get-files date))
              (dates (delq nil (mapcar #'denote-journal-calendar--file-to-date files))))
    (dolist (date dates)
      (when (calendar-date-is-visible-p date)
        (calendar-mark-visible-date date 'denote-journal-calendar)))))

(defun denote-journal-calendar--date-to-time (calendar-date)
  "Return internal time of `calendar' CALENDAR-DATE.
CALENDAR-DATE is a list of three numbers, in the form of (MONTH DAY YEAR)."
  (pcase-let ((`(,month ,day ,year) calendar-date)
              (time (format-time-string "%T")))
    (date-to-time (format "%s-%02d-%02d %s" year month day time))))

(defun denote-journal-calendar--date-to-identifier (calendar-date)
  "Return path to Denote journal entry corresponding to CALENDAR-DATE.
CALENDAR-DATE is a list of three numbers, in the form of (MONTH DAY YEAR)."
  (when-let* ((date (denote-journal-calendar--date-to-time calendar-date)))
    (denote-journal--entry-today date)))

(defun denote-journal-calendar-find-file ()
  "Show the Denote journal entry for the `calendar' date at point.
If there are more than one files, prompt with completion to select one
among them."
  (declare (interactive-only t))
  (interactive nil calendar-mode)
  (unless (derived-mode-p 'calendar-mode)
    (user-error "Only use this command inside the `calendar'"))
  (when-let* ((calendar-date (calendar-cursor-to-date)))
    (if-let* ((files (denote-journal-calendar--date-to-identifier calendar-date))
              (file (denote-journal-select-file-prompt files)))
        (funcall denote-open-link-function file)
      (user-error "No Denote journal entry for this date"))))

(defun denote-journal-calendar-new-or-existing ()
  "Like `denote-journal-new-or-existing-entry' for the `calendar' date at point."
  (declare (interactive-only t))
  (interactive nil calendar-mode)
  (unless (derived-mode-p 'calendar-mode)
    (user-error "Only use this command inside the `calendar'"))
  (when-let* ((calendar-date (calendar-cursor-to-date)))
    (if-let* ((internal (denote-journal-calendar--date-to-time calendar-date)))
        (progn
          (calendar-mark-visible-date calendar-date 'denote-journal-calendar)
          ;; Do not use the same `calendar' window...
          (cl-letf (((symbol-function #'find-file) denote-open-link-function))
            (denote-journal-new-or-existing-entry internal)))
      (user-error "No Denote journal entry for this date"))))

(defvar denote-journal-calendar-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "N" #'denote-journal-calendar-new-or-existing)
    (define-key map "F" #'denote-journal-calendar-find-file)
    map)
  "Key map for `denote-journal-calendar-mode'.")

(define-minor-mode denote-journal-calendar-mode
  "Mark Denote journal entries using `denote-journal-calendar' face.
Add the function `denote-journal-calendar-mode' to the
`calendar-mode-hook' for changes to take effect."
  :global nil
  (if denote-journal-calendar-mode
      (dolist (hook '(calendar-today-visible-hook calendar-today-invisible-hook))
        (add-hook hook #'denote-journal-calendar-mark-dates nil :local))
    (dolist (hook '(calendar-today-visible-hook calendar-today-invisible-hook))
      (remove-hook hook #'denote-journal-calendar-mark-dates :local))))

(provide 'denote-journal)
;;; denote-journal.el ends here

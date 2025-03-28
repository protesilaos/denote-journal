;;; denote-journal.el --- Convenience functions for daily journaling with Denote -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2025  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://github.com/protesilaos/denote-journal
;; Version: 0.0.0.1
;; Package-Requires: ((emacs "28.1") (denote "3.1.0"))

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
The value is either a symbol or an arbitrary string that is
passed to `format-time-string' (consult its documentation for the
technicalities).

Acceptable symbols and their corresponding styles are:

| Symbol                  | Style                             |
|-------------------------+-----------------------------------|
| day                     | Monday                            |
| day-date-month-year     | Monday 19 September 2023          |
| day-date-month-year-24h | Monday 19 September 2023 20:49    |
| day-date-month-year-12h | Monday 19 September 2023 08:49 PM |

With a nil value, make `denote-journal-new-entry' prompt
for a title."
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
  "Return present date in `denote-journal-title-format' or prompt for title.
With optional DATE, use it instead of the present date.  DATE has
the same format as that returned by `current-time'."
  (format-time-string
   (if (and denote-journal-title-format
            (stringp denote-journal-title-format))
       denote-journal-title-format
     (pcase denote-journal-title-format
       ('day "%A")
       ('day-date-month-year "%A %e %B %Y")
       ('day-date-month-year-24h "%A %e %B %Y %H:%M")
       ('day-date-month-year-12h "%A %e %B %Y %I:%M %^p")
       (_ (denote-title-prompt (format-time-string "%F" date)))))
   date))

(defun denote-journal--get-template ()
  "Return template that has `journal' key in `denote-templates'.
If no template with `journal' key exists but `denote-templates'
is non-nil, prompt the user for a template among
`denote-templates'.  Else return nil.

Also see `denote-journal-new-entry'."
  (if-let* ((template (alist-get 'journal denote-templates)))
      template
    (when denote-templates
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
  (let ((denote-directory (file-name-as-directory (denote-journal-directory))))
    (denote-directory-files (denote-journal--filename-date-regexp date))))

;;;###autoload
(defun denote-journal-path-to-new-or-existing-entry (&optional date)
  "Return path to existing or new journal file.
With optional DATE, do it for that date, else do it for today.  DATE is
a string and has the same format as that covered in the documentation of
the `denote' function.  It is internally processed by
`denote-valid-date-p'.

If there are multiple journal entries for the date, prompt for one among
them using minibuffer completion.  If there is only one, return it.  If
there is no journal entry, create it."
  (let* ((internal-date (or (denote-valid-date-p date) (current-time)))
         (files (denote-journal--entry-today internal-date)))
    (cond
     ((length> files 1)
      (completing-read "Select journal entry: " files nil t))
     (files
      (car files))
     (t
      (save-window-excursion
        (denote-journal-new-entry date)
        (save-buffer)
        (buffer-file-name))))))

;;;###autoload
(defun denote-journal-new-or-existing-entry (&optional date)
  "Locate an existing journal entry or create a new one.
A journal entry is one that has the value of the variable
`denote-journal-keyword' as part of its file name.

If there are multiple journal entries for the current date,
prompt for one using minibuffer completion.  If there is only
one, visit it outright.  If there is no journal entry, create one
by calling `denote-journal-extra-new-entry'.

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
by calling `denote-journal-extra-new-entry' and link to it.

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

(provide 'denote-journal)
;;; denote-journal.el ends here

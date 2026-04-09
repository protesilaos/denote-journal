;;; denote-journal.el --- Convenience functions for daily journaling with Denote -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2026  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://github.com/protesilaos/denote-journal
;; Version: 0.2.2
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

;;;; User options

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
  "The keyword to use in new journal entries.
This is used by `denote-journal-new-entry' and related commands.

The value can be one among the following

- nil, which means to not use any keyword;
- a string, which means to use that as the keyword;
- a list of strings, which means to use those as the keywords;
- a function that returns a string or list of strings.

The function may involve user input and can even be the
`denote-keywords-prompt'."
  :group 'denote-journal
  :type '(choice
          (const :tag "No keywords" nil)
          (string :tag "Single Keyword")
          (repeat :tag "List of keywords" string)
          (function :tag "Function that returns a string or list of strings"))
  :package-version '(denote . "0.2.0"))

(defcustom denote-journal-signature nil
  "The signature to use in new journal entries.
This is used by `denote-journal-new-entry' and related commands.

The value can be one among the following:

- nil, which means to not use a predefined signature;
- a string, which is used as-is;
- a function that returns a string, which is then used as-is.

In the case of a function, users may wish to integrate the
`denote-journal' package with `denote-sequence'.  For example, each new
journal entry should be defined as a new parent sequence.  Thus:

    (setq denote-journal-signature
          (lambda ()
            (denote-sequence-get-new (quote parent))))"
  :type '(choice
          (const :tag "No predefined signature" nil)
          (string :tag "The predefined signature to use for new entries")
          (function :tag "Function that returns a string"))
  :group 'denote-journal
  :package-version '(denote . "0.2.0"))

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

(defcustom denote-journal-identifier-format nil
  "Date format of journal note identifiers.
When nil, journal entries use the prevailing value of
`denote-get-identifier-function'.  When the value is a string, it is
used as `denote-date-identifier-format' for
`denote-generate-identifier-as-date' in
`denote-journal-new-entry'.  The string is interpreted by
`format-time-string'.

Because this relies on Denote's date-based identifier generator,
custom values should remain compatible with that function and with
`date-to-time'.  Journal entry lookup is based on each note's date
field, so changing the identifier format does not affect
existing-or-new journal commands."
  :group 'denote-journal
  :type '(choice
          (const :tag "Use Denote's prevailing identifier generation" nil)
          (string :tag "Custom string with `format-time-string' specifiers")))

(defcustom denote-journal-interval 'daily
  "The interval used by `denote-journal-new-or-existing-entry'.
The value is a symbol of `daily', `weekly', `monthly', or `yearly'.  Any
other value is understood as `daily'."
  :type '(choice
          (const daily)
          (const weekly)
          (const monthly)
          (const yearly))
  :package-version '(denote . "0.2.0")
  :group 'denote-journal)

(defcustom denote-journal-hook nil
  "Normal hook called after `denote-journal-new-entry'.
Use this to, for example, set a timer after starting a new
journal entry (refer to the `tmr' package on GNU ELPA)."
  :group 'denote-journal
  :type 'hook)

;;;; Common helper functions

(defun denote-journal-directory ()
  "Return the variable `denote-journal-directory' as a directory.
If the path does not exist, then make it first."
  (if-let* (((stringp denote-journal-directory))
            (directory (file-name-as-directory (expand-file-name denote-journal-directory))))
      (progn
        (when (not (file-directory-p denote-journal-directory))
          (make-directory directory :parents))
        directory)
    (car (denote-directories))))

(defun denote-journal-keyword ()
  "Return the value of the variable `denote-journal-keyword' as a list."
  (cond
   ((proper-list-p denote-journal-keyword)
    denote-journal-keyword)
   ((stringp denote-journal-keyword)
    (list denote-journal-keyword))
   ((functionp denote-journal-keyword)
    (when-let* ((value (funcall denote-journal-keyword))
                (denote-journal-keyword value))
      (denote-journal-keyword)))
   (t nil)))

(defun denote-journal-signature ()
  "Return the value of the variable `denote-journal-signature'."
  (cond
   ((stringp denote-journal-signature) denote-journal-signature)
   ((functionp denote-journal-signature)
    (when-let* ((value (funcall denote-journal-signature))
                (denote-journal-signature value))
      (denote-journal-signature)))
   (t nil)))

(defun denote-journal--keyword-regex ()
  "Return a regular expression string that matches the journal keyword(s)."
  (if-let* ((keywords-sorted (mapcar #'regexp-quote (denote-keywords-sort (denote-journal-keyword)))))
      (concat "_" (string-join keywords-sorted ".*_"))
    ".*"))

(defun denote-journal-file-is-journal-p (file)
  "Return non-nil if FILE is a journal entry."
  (and (denote-file-has-denoted-filename-p file)
       (string-match-p (denote-journal--keyword-regex) (file-name-nondirectory file))
       (file-in-directory-p file (denote-journal-directory))))

(defun denote-journal-filename-is-journal-p (filename)
  "Return non-nil if FILENAME is a valid name for a journal entry."
  (and (denote-file-has-denoted-filename-p filename)
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
                      ('day-date-month-year "%A %-e %B %Y")
                      ('day-date-month-year-24h "%A %-e %B %Y %H:%M")
                      ('day-date-month-year-12h "%A %-e %B %Y %I:%M %^p"))))
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

;;;; New entry without special conditions

;;;###autoload
(defun denote-journal-new-entry (&optional date)
  "Create a new journal entry in variable `denote-journal-directory'.
Use the variable `denote-journal-keyword' as a keyword for the
newly created file.  Set the title of the new entry according to the
value of the user option `denote-journal-title-format'.  When
`denote-journal-identifier-format' is non-nil, use it to construct
the identifier of the new entry.

With optional DATE as a prefix argument, prompt for a date.  If
`denote-date-prompt-use-org-read-date' is non-nil, use the Org
date selection module.

When called from Lisp DATE is a string and has the same format as
that covered in the documentation of the `denote' function.  It
is internally processed by `denote-valid-date-p'."
  (interactive (list (when current-prefix-arg (denote-date-prompt))))
  (let ((internal-date (or (denote-valid-date-p date) (current-time)))
        (denote-directory (denote-journal-directory))
        (denote-date-identifier-format
         (or denote-journal-identifier-format denote-date-identifier-format))
        (denote-get-identifier-function
         (if denote-journal-identifier-format
             #'denote-generate-identifier-as-date
           denote-get-identifier-function)))
    (denote
     (denote-journal-daily--title-format internal-date)
     (denote-journal-keyword)
     nil nil date
     (denote-journal--get-template)
     (denote-journal-signature))
    (run-hooks 'denote-journal-hook)))

;;;; New or existing entry based on `denote-journal-interval'

(defun denote-journal--filename-regexp (date interval)
  "Regular expression for Denote files with DATE matched to INTERVAL.
INTERVAL is one among the symbols used by `denote-journal-interval'.
DATE has the same format as that returned by `denote-valid-date-p'."
  (let* ((identifier
          (pcase interval
            ('weekly
             (let* ((day-of-week (string-to-number (format-time-string "%u" date)))
                    (monday (time-subtract date (seconds-to-time (* (1- day-of-week) 24 3600))))
                    (date-strings
                     (let ((list nil))
                       (dotimes (i 7)
                         (push (format-time-string "%Y%m%d" (time-add monday (seconds-to-time (* i 24 3600)))) list))
                       (nreverse list)))
                    (date-regexp (regexp-opt date-strings)))
               (format "%sT[0-9]\\{6\\}" date-regexp)))
            ('monthly (format "%s[0-9]\\{2\\}T[0-9]\\{6\\}" (format-time-string "%Y%m" date)))
            ('yearly (format "%s[0-9]\\{4\\}T[0-9]\\{6\\}" (format-time-string "%Y" date)))
            (_ (format "%sT[0-9]\\{6\\}" (format-time-string "%Y%m%d" date)))))
         (order denote-file-name-components-order)
         (id-index (seq-position order 'identifier))
         (kw-index (seq-position order 'keywords)))
    (if (> kw-index id-index)
        (format "%s.*?%s" identifier (denote-journal--keyword-regex))
      (format "%s.*?@@%s" (denote-journal--keyword-regex) identifier))))

(defun denote-journal--date-in-interval-p (date interval)
  "Return DATE if it is within the INTERVAL else nil.
INTERVAL is one among the symbols used by `denote-journal-interval'.
DATE has the same format as that returned by `denote-valid-date-p'."
  (if-let* ((date (denote-valid-date-p date))
            (current (current-time))
            (specifiers (pcase interval
                          ('weekly "%Y-%V")
                          ('monthly "%Y-%m")
                          ('yearly "%Y")
                          (_ t))))
      (cond
       ((eq specifiers t)
        date)
       ((string= (format-time-string specifiers date)
                 (format-time-string specifiers current))
        date))
    (error "The date `%s' does not satisfy `denote-valid-date-p'" date)))

(defun denote-journal--same-interval-p (date-a date-b interval)
  "Return non-nil if DATE-A and DATE-B fall within the same INTERVAL.
INTERVAL is one among the symbols used by `denote-journal-interval'.
DATE-A and DATE-B have the same format as that returned by
`current-time'."
  (let ((specifiers (pcase interval
                      ('weekly "%Y-%V")
                      ('monthly "%Y-%m")
                      ('yearly "%Y")
                      (_ "%F"))))
    (string=
     (format-time-string specifiers date-a)
     (format-time-string specifiers date-b))))

(defun denote-journal--directory-files ()
  "Return all journal files in `denote-journal-directory'."
  (let ((denote-directory (denote-journal-directory)))
    (denote-directory-files (denote-journal--keyword-regex))))

(defun denote-journal--retrieve-file-date (file)
  "Return FILE date as an internal time value."
  (or
   (when-let* ((file-type (denote-filetype-heuristics file))
               (date-value (denote-retrieve-front-matter-date-value file file-type)))
     (denote-valid-date-p date-value))
   (when-let* ((identifier (denote-retrieve-filename-identifier file))
               (date-value (ignore-errors (denote-id-to-date identifier))))
     (denote-valid-date-p date-value))))

(defun denote-journal--get-entry (date interval)
  "Return list of files matching a journal for DATE given INTERVAL.
INTERVAL is one among the symbols used by `denote-journal-interval'.
DATE has the same format as that returned by `denote-valid-date-p'."
  (let ((target-date (or (denote-valid-date-p date) (current-time))))
    (seq-filter
     (lambda (file)
       (when-let* ((file-date (denote-journal--retrieve-file-date file)))
         (denote-journal--same-interval-p file-date target-date interval)))
     (denote-journal--directory-files))))

(defun denote-journal-select-file-prompt (files)
  "Prompt for file among FILES if >1, else return the `car'.
Perform the operation relative to the variable `denote-journal-directory'."
  (let* ((default-directory (denote-journal-directory))
         (denote-directory default-directory)
         (relative-files (mapcar #'denote-get-file-name-relative-to-denote-directory files))
         (file (if (> (length files) 1)
                   (completing-read
                    "Select journal entry: "
                    (apply 'denote-get-completion-table relative-files denote-file-prompt-extra-metadata)
                    nil t)
                 (car relative-files))))
    (concat denote-directory file)))

;;;###autoload
(defun denote-journal-path-to-new-or-existing-entry (&optional date interval)
  "Return path to existing or new journal file.
With optional DATE, do it for that date, else do it for today.  DATE is
a string and has the same format as that covered in the documentation of
the `denote' function.  It is internally processed by `denote-valid-date-p'.

If there are multiple journal entries for the date, prompt for one among
them using minibuffer completion.  If there is only one, return it.  If
there is no journal entry, create it.

With optional INTERVAL as a symbol among those accepted by
`denote-journal-interval', match DATE to INTERVAL and then return the
results accordingly.  If INTERVAL is nil, then it has the same measing
as `daily', per `denote-journal-interval'."
  (let* ((internal-date (denote-journal--date-in-interval-p (or date (current-time)) interval))
         (files (denote-journal--get-entry internal-date interval))
         (denote-kill-buffers nil))
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
It is internally processed by `denote-valid-date-p'.

Consult the user option `denote-journal-interval' to determine when to
create a new file or visit an existing one."
  (interactive
   (list
    (when current-prefix-arg
      (denote-date-prompt))))
  (if-let* ((date-to-use (or date (current-time)))
            (file (denote-journal-path-to-new-or-existing-entry date-to-use denote-journal-interval)))
      (find-file file)
    (error "Cannot get a new or existing journal entry")))

;;;; Link or create functionality

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

(defface denote-journal-calendar
  '((((supports :box t))
     :box (:line-width (-1 . -1)))
    (t :inverse-video t))
  "Face to mark a Denote journal entry in the `calendar'.")

(defun denote-journal-calendar--file-to-date (file)
  "Convert FILE to calendar date by interpreting its note date."
  (when-let* ((date (denote-journal--retrieve-file-date file))
              (numbers (mapcar #'string-to-number
                               (split-string (format-time-string "%F" date) "-"))))
    (pcase-let ((`(,year ,month ,day) numbers))
      (list month day year))))

(defun denote-journal-calendar--get-files (_calendar-date)
  "Return journal files in variable `denote-journal-directory'."
  (denote-journal--directory-files))

(defun denote-journal-calendar-mark-dates ()
  "Mark visible days in the `calendar' that have a Denote journal entry."
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
    (denote-journal--get-entry date denote-journal-interval)))

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

;;;###autoload
(define-minor-mode denote-journal-calendar-mode
  "Mark Denote journal entries using `denote-journal-calendar' face.
Add the function `denote-journal-calendar-mode' to the
`calendar-mode-hook' for changes to take effect."
  :global nil
  (dolist (hook '(calendar-today-visible-hook calendar-today-invisible-hook))
    (if denote-journal-calendar-mode
        (add-hook hook #'denote-journal-calendar-mark-dates nil :local)
      (remove-hook hook #'denote-journal-calendar-mark-dates :local))))

(provide 'denote-journal)
;;; denote-journal.el ends here

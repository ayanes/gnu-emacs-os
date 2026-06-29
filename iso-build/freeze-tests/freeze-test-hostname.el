;;; freeze-test-hostname.el --- hostname validation freeze-tests -*- lexical-binding: t -*-

;; Author: Borja Tarraso <borja.tarraso@member.fsf.org>
;; SPDX-License-Identifier: GPL-3.0-or-later
;; Copyright (C) 2025-2026  Borja Tarraso <borja.tarraso@member.fsf.org>
;;
;; This file is part of GEOS.
;;
;; GEOS is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; GEOS is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GEOS.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; pins `hostname--validation-failure' and `hostname--validate' in
;; emacs-init/core/hostname.el.  the smoke-test boots with a valid
;; /etc/hostname but never exercises the rejection paths (empty file,
;; oversize name, illegal characters); a regression that widens the
;; regexp or drops the 63-byte cap would still PASS the boot gate.
;;
;; tests:
;;
;;   hostname/valid-samples
;;     asserts known-good short names (lambda, geos-hurd, a, ab, a-b)
;;     pass validation and round-trip through `hostname--validate'.
;;
;;   hostname/invalid-samples
;;     asserts empty, too-long (64 chars), leading/trailing hyphen,
;;     dots, uppercase, and whitespace each map to the documented
;;     failure symbol and yield nil from `hostname--validate'.
;;
;;   hostname/read-fixture
;;     writes a temp /etc/hostname stand-in, rebinds `hostname-file',
;;     calls `hostname--read', and asserts trim + validate work
;;     end-to-end.

;;; Code:

(require 'cl-lib)

(defun freeze-test--hostname-record (tag result)
  "Bridge to the main freeze-test recorder when present."
  (cond
   ((fboundp 'freeze-test--record)
    (freeze-test--record tag result))
   (t
    (message "freeze-test-hostname: %S -> %S" tag result))))

(defun freeze-test/hostname-valid-samples ()
  "Pin `hostname--validate' accepts RFC-shaped lowercase names."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'hostname--validate))
      (setq result (cons 'skip "hostname--validate unbound")))
     (t
      (let ((good '("lambda" "geos-hurd" "a" "ab" "a-b" "x9" "9x"))
            (mismatches nil))
        (dolist (name good)
          (cond
           ((hostname--validation-failure name)
            (push (list :failure name (hostname--validation-failure name))
                  mismatches))
           ((not (equal (hostname--validate name) name))
            (push (list :validate name (hostname--validate name)) mismatches))))
        (setq result (if (null mismatches) 'pass mismatches)))))
    (freeze-test--hostname-record 'hostname/valid-samples result)
    result))

(defun freeze-test/hostname-invalid-samples ()
  "Pin `hostname--validation-failure' rejects malformed names."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'hostname--validation-failure))
      (setq result (cons 'skip "hostname--validation-failure unbound")))
     (t
      (let* ((too-long (make-string 64 ?a))
             (cases (list (cons "" 'empty)
                          (cons "   " 'bad-syntax)
                          (cons too-long 'too-long)
                          (cons "-bad" 'bad-syntax)
                          (cons "bad-" 'bad-syntax)
                          (cons "bad.name" 'bad-syntax)
                          (cons "bad_name" 'bad-syntax)
                          (cons "has space" 'bad-syntax)
                          (cons "geos_mode" 'bad-syntax)))
             (mismatches nil))
        (dolist (pair cases)
          (let* ((s (car pair))
                 (want (cdr pair))
                 (got (hostname--validation-failure s)))
            (unless (eq got want)
              (push (list :input s :got got :want want) mismatches))
            (when (hostname--validate s)
              (push (list :validate-should-nil s) mismatches))))
        (setq result (if (null mismatches) 'pass mismatches)))))
    (freeze-test--hostname-record 'hostname/invalid-samples result)
    result))

(defun freeze-test/hostname-read-fixture ()
  "Pin `hostname--read' trims and validates a temp hostname file."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'hostname--read))
      (setq result (cons 'skip "hostname--read unbound")))
     (t
      (let* ((tmp (make-temp-file "freeze-test-hostname-"))
             (mismatches nil))
        (unwind-protect
            (progn
              (write-region "  geos-fixture  \n" nil tmp nil 'silent)
              (let ((hostname-file tmp))
                (unless (equal (hostname--read) "geos-fixture")
                  (push (list :read (hostname--read) :want "geos-fixture")
                        mismatches)))
              (write-region "-invalid-\n" nil tmp nil 'silent)
              (let ((hostname-file tmp))
                (when (hostname--read)
                  (push (list :reject (hostname--read)) mismatches))))
          (when (file-exists-p tmp) (delete-file tmp)))
        (setq result (if (null mismatches) 'pass mismatches)))))
    (freeze-test--hostname-record 'hostname/read-fixture result)
    result))

(defun freeze-test-hostname ()
  "Run hostname validation freeze-tests.
Records three results under hostname/* tags; returns nil."
  (interactive)
  (freeze-test/hostname-valid-samples)
  (freeze-test/hostname-invalid-samples)
  (freeze-test/hostname-read-fixture)
  nil)

(provide 'freeze-test-hostname)
;;; freeze-test-hostname.el ends here

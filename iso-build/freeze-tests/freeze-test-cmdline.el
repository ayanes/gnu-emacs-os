;;; freeze-test-cmdline.el --- /proc/cmdline parser freeze-tests -*- lexical-binding: t -*-

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
;; pins emacs-init/core/cmdline.el beyond the login-abuse slice that
;; only exercises `geos.login=skip'.  the shared parser has two
;; predicates (`geos-cmdline-token-p' and `geos-cmdline-key-present-p')
;; with different right-edge rules; this file locks both down against
;; synthetic fixture files via `geos-cmdline-path' rebinding.
;;
;; tests:
;;
;;   cmdline/token-exact
;;     literal-token match: whole tokens hit, substring near-misses miss.
;;
;;   cmdline/key-prefix
;;     prefix match for `geos.mode=': ui/console hit, not-geos.mode= miss.
;;
;;   cmdline/tokenize-trim
;;     `geos-cmdline-tokens' drops leading/trailing/newline whitespace.

;;   cmdline/key-prefix-no-false-positive
;;     `geos.mode=' is absent when the only mode-ish token is
;;     `not-geos.mode=ui'.

;;; Code:

(require 'cl-lib)

(defun freeze-test--cmdline-record (tag result)
  "Bridge to the main freeze-test recorder when present."
  (cond
   ((fboundp 'freeze-test--record)
    (freeze-test--record tag result))
   (t
    (message "freeze-test-cmdline: %S -> %S" tag result))))

(defun freeze-test--cmdline-with-fixture (contents body)
  "Run BODY with `geos-cmdline-path' bound to a temp file holding CONTENTS."
  (let ((tmp (make-temp-file "freeze-test-cmdline-")))
    (unwind-protect
        (progn
          (write-region contents nil tmp nil 'silent)
          (let ((geos-cmdline-path tmp))
            (funcall body)))
      (when (file-exists-p tmp) (delete-file tmp)))))

(defun freeze-test/cmdline-token-exact ()
  "Pin `geos-cmdline-token-p' requires whole-token equality."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'geos-cmdline-token-p))
      (setq result (cons 'skip "geos-cmdline-token-p unbound")))
     (t
      (setq result
            (freeze-test--cmdline-with-fixture
             "root=UUID=abc geos.login=skip geos.login=skipnot\n"
             (lambda ()
               (let ((mismatches nil))
                 (unless (geos-cmdline-token-p "geos.login=skip")
                   (push :want-skip mismatches))
                 (unless (geos-cmdline-token-p "geos.login=skipnot")
                   (push :want-skipnot-token mismatches))
                 (when (geos-cmdline-token-p "geos.login=skipx")
                   (push :reject-near-miss mismatches))
                 (if (null mismatches) 'pass mismatches)))))))
    (freeze-test--cmdline-record 'cmdline/token-exact result)
    result))

(defun freeze-test/cmdline-key-prefix ()
  "Pin `geos-cmdline-key-present-p' prefix match on `geos.mode='."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'geos-cmdline-key-present-p))
      (setq result (cons 'skip "geos-cmdline-key-present-p unbound")))
     (t
      (setq result
            (freeze-test--cmdline-with-fixture
             "quiet not-geos.mode=ui geos.mode=console\n"
             (lambda ()
               (let ((mismatches nil))
                 (unless (geos-cmdline-key-present-p "geos.mode=")
                   (push :want-mode-key mismatches))
                 (when (geos-cmdline-key-present-p "geos.login=")
                   (push :reject-login-key mismatches))
                 (if (null mismatches) 'pass mismatches)))))))
    (freeze-test--cmdline-record 'cmdline/key-prefix result)
    result))

(defun freeze-test/cmdline-tokenize-trim ()
  "Pin `geos-cmdline-tokens' splits on whitespace and drops empties."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'geos-cmdline-tokens))
      (setq result (cons 'skip "geos-cmdline-tokens unbound")))
     (t
      (setq result
            (freeze-test--cmdline-with-fixture
             "  foo\tbar\nbaz  \n"
             (lambda ()
               (let* ((got (geos-cmdline-tokens))
                      (want '("foo" "bar" "baz")))
                 (if (equal got want) 'pass (list :got got :want want))))))))
    (freeze-test--cmdline-record 'cmdline/tokenize-trim result)
    result))

(defun freeze-test/cmdline-key-prefix-no-false-positive ()
  "Pin `geos-cmdline-key-present-p' rejects the not-geos.mode= trap."
  (interactive)
  (let ((result 'fail))
    (cond
     ((not (fboundp 'geos-cmdline-key-present-p))
      (setq result (cons 'skip "geos-cmdline-key-present-p unbound")))
     (t
      (setq result
            (freeze-test--cmdline-with-fixture
             "quiet not-geos.mode=ui\n"
             (lambda ()
               (if (geos-cmdline-key-present-p "geos.mode=")
                   'fail
                 'pass))))))
    (freeze-test--cmdline-record 'cmdline/key-prefix-no-false-positive result)
    result))

(defun freeze-test-cmdline ()
  "Run cmdline parser freeze-tests.
Records four results under cmdline/* tags; returns nil."
  (interactive)
  (freeze-test/cmdline-token-exact)
  (freeze-test/cmdline-key-prefix)
  (freeze-test/cmdline-key-prefix-no-false-positive)
  (freeze-test/cmdline-tokenize-trim)
  nil)

(provide 'freeze-test-cmdline)
;;; freeze-test-cmdline.el ends here

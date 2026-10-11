;;; claude-code-ide-companion-tests.el --- Tests for claude-code-ide-companion  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Piotr Kwiecinski

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Test suite for claude-code-ide-companion.el using ERT.
;;
;; Run tests with:
;;   emacs -batch -L . -l ert -l claude-code-ide-companion-tests.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)

;; Mock claude-code-ide dependencies before loading companion
(cl-defstruct claude-code-ide-mcp-session
  session-id instance-name buffer process last-used project-dir)

(defvar claude-code-ide-companion-tests--sessions nil
  "Mock session registry.")

(defun claude-code-ide-mcp--active-sessions ()
  "Mock: return all sessions."
  claude-code-ide-companion-tests--sessions)

(defun claude-code-ide-mcp--sessions-for-project (project-dir)
  "Mock: return sessions for PROJECT-DIR."
  (cl-remove-if-not (lambda (s) (equal (claude-code-ide-mcp-session-project-dir s)
                                       project-dir))
                    claude-code-ide-companion-tests--sessions))

(defun claude-code-ide--get-working-directory ()
  "Mock: return current project directory."
  default-directory)

(defun claude-code-ide--display-buffer-in-side-window (_buffer)
  "Mock: display BUFFER in side window."
  nil)

(provide 'claude-code-ide-mcp)
(provide 'claude-code-ide)

(require 'claude-code-ide-companion)

;;; Helpers

(defmacro claude-code-ide-companion-tests--with-sessions (sessions &rest body)
  "Run BODY with the mock registry bound to SESSIONS."
  (declare (indent 1))
  `(let ((claude-code-ide-companion-tests--sessions ,sessions))
     ,@body))

(defun claude-code-ide-companion-tests--session (dir buffer &optional process last-used)
  "Make a mock session for DIR with BUFFER, PROCESS and LAST-USED."
  (make-claude-code-ide-mcp-session
   :project-dir dir :buffer buffer :process process :last-used last-used))

;;; Tests

(ert-deftest claude-code-ide-companion-test-close-visible-sessions ()
  "Test that visible Claude windows are closed."
  (let* ((buf1 (get-buffer-create "*claude-code[project1]*"))
         (buf2 (get-buffer-create "*claude-code[project2]*"))
         (deleted-windows '()))
    (unwind-protect
        (claude-code-ide-companion-tests--with-sessions
            (list (claude-code-ide-companion-tests--session "/dir/project1/" buf1)
                  (claude-code-ide-companion-tests--session "/dir/project2/" buf2))
          (cl-letf (((symbol-function 'get-buffer-window)
                     (lambda (buf) (when (eq buf buf1) 'win1)))
                    ((symbol-function 'delete-window)
                     (lambda (win) (push win deleted-windows))))
            (claude-code-ide-companion--close-visible-sessions)
            (should (equal deleted-windows '(win1)))))
      (kill-buffer buf1)
      (kill-buffer buf2))))

(ert-deftest claude-code-ide-companion-test-on-context-switch-shows-session ()
  "Test that switching to a project shows its most recently used live session."
  (let* ((project-dir "/test/project/")
         (old-buf (get-buffer-create "*claude-code[project:old]*"))
         (new-buf (get-buffer-create "*claude-code[project]*"))
         (dead-buf (get-buffer-create "*claude-code[project:dead]*"))
         (live (start-process "mock-live" nil "sleep" "60"))
         (displayed-buffer nil))
    (unwind-protect
        (claude-code-ide-companion-tests--with-sessions
            (list (claude-code-ide-companion-tests--session project-dir old-buf live 1.0)
                  (claude-code-ide-companion-tests--session project-dir new-buf live 2.0)
                  (claude-code-ide-companion-tests--session project-dir dead-buf nil 3.0))
          (cl-letf (((symbol-function 'claude-code-ide--get-working-directory)
                     (lambda () project-dir))
                    ((symbol-function 'claude-code-ide-companion--close-visible-sessions)
                     #'ignore)
                    ((symbol-function 'claude-code-ide--display-buffer-in-side-window)
                     (lambda (buf) (setq displayed-buffer buf))))
            (claude-code-ide-companion--on-context-switch)
            (should (eq displayed-buffer new-buf))))
      (delete-process live)
      (mapc #'kill-buffer (list old-buf new-buf dead-buf)))))

(ert-deftest claude-code-ide-companion-test-on-context-switch-closes-windows-no-session ()
  "Test that switching to a project without a session closes visible Claude windows."
  (let* ((other-buf (get-buffer-create "*claude-code[other]*"))
         (live (start-process "mock-other" nil "sleep" "60"))
         (close-visible-called nil)
         (displayed-buffer nil))
    (unwind-protect
        (claude-code-ide-companion-tests--with-sessions
            (list (claude-code-ide-companion-tests--session "/test/other/" other-buf live))
          (cl-letf (((symbol-function 'claude-code-ide--get-working-directory)
                     (lambda () "/test/new-project/"))
                    ((symbol-function 'claude-code-ide-companion--close-visible-sessions)
                     (lambda () (setq close-visible-called t)))
                    ((symbol-function 'claude-code-ide--display-buffer-in-side-window)
                     (lambda (buf) (setq displayed-buffer buf))))
            (claude-code-ide-companion--on-context-switch)
            (should close-visible-called)
            (should (null displayed-buffer))))
      (delete-process live)
      (kill-buffer other-buf))))

(ert-deftest claude-code-ide-companion-test-mode-installs-advice ()
  "Test that enabling the mode installs advice."
  (unwind-protect
      (progn
        (claude-code-ide-companion-project-switch-mode 1)
        (should (advice-member-p #'claude-code-ide-companion--on-context-switch 'project-switch-project)))
    (claude-code-ide-companion-project-switch-mode -1)))

(ert-deftest claude-code-ide-companion-test-mode-removes-advice ()
  "Test that disabling the mode removes advice."
  (claude-code-ide-companion-project-switch-mode 1)
  (claude-code-ide-companion-project-switch-mode -1)
  (should-not (advice-member-p #'claude-code-ide-companion--on-context-switch 'project-switch-project)))

(defun claude-code-ide-companion-run-tests ()
  "Run all claude-code-ide-companion tests."
  (interactive)
  (ert-run-tests-interactively "^claude-code-ide-companion-test-"))

(provide 'claude-code-ide-companion-tests)

;;; claude-code-ide-companion-tests.el ends here

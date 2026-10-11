;;; claude-code-ide-companion.el --- Extra features for claude-code-ide  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Piotr Kwiecinski

;; Author: Piotr Kwiecinski
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (claude-code-ide "0.3.0"))
;; Keywords: ai, claude, code, assistant
;; URL: https://github.com/piotrkwiecinski/claude-code-ide-companion.el

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Extra features for claude-code-ide.el that extend the core package
;; with additional integrations.
;;
;; Currently provides:
;; - Automatic Claude Code window switching when changing projects
;;   via `project-switch-project'.
;;
;; Usage:
;;   (require 'claude-code-ide-companion)
;;   (claude-code-ide-companion-project-switch-mode 1)

;;; Code:

(require 'cl-lib)
(require 'claude-code-ide)
(require 'claude-code-ide-mcp)

(defgroup claude-code-ide-companion nil
  "Extra features for Claude Code IDE."
  :group 'claude-code-ide
  :prefix "claude-code-ide-companion-")

(defun claude-code-ide-companion--live-session-p (session)
  "Return non-nil when SESSION has a live buffer and terminal process."
  (let ((buffer (claude-code-ide-mcp-session-buffer session))
        (process (claude-code-ide-mcp-session-process session)))
    (and buffer (buffer-live-p buffer)
         process (process-live-p process))))

(defun claude-code-ide-companion--project-session (directory)
  "Return the most recently used live session for DIRECTORY, or nil."
  (car (sort (cl-remove-if-not #'claude-code-ide-companion--live-session-p
                               (claude-code-ide-mcp--sessions-for-project directory))
             (lambda (a b)
               (> (or (claude-code-ide-mcp-session-last-used a) 0)
                  (or (claude-code-ide-mcp-session-last-used b) 0))))))

(defun claude-code-ide-companion--close-visible-sessions ()
  "Close all visible Claude Code side windows."
  (dolist (session (claude-code-ide-mcp--active-sessions))
    (when-let* ((buf (claude-code-ide-mcp-session-buffer session))
                ((buffer-live-p buf))
                (win (get-buffer-window buf)))
      (delete-window win))))

(defun claude-code-ide-companion--on-context-switch (&rest _args)
  "Update Claude Code side window after switching projects.
If a Claude Code session exists for the current project, display its
most recently used instance.  Otherwise, close any visible Claude Code
side windows."
  (let ((session (claude-code-ide-companion--project-session
                  (claude-code-ide--get-working-directory))))
    (claude-code-ide-companion--close-visible-sessions)
    (when session
      (claude-code-ide--display-buffer-in-side-window
       (claude-code-ide-mcp-session-buffer session)))))

;;;###autoload
(define-minor-mode claude-code-ide-companion-project-switch-mode
  "Toggle extra features for Claude Code IDE.
When enabled, automatically follows project switches to show the
appropriate Claude Code session."
  :global t
  :group 'claude-code-ide-companion
  (if claude-code-ide-companion-project-switch-mode
      (advice-add 'project-switch-project :after #'claude-code-ide-companion--on-context-switch)
    (advice-remove 'project-switch-project #'claude-code-ide-companion--on-context-switch)))

(provide 'claude-code-ide-companion)

;;; claude-code-ide-companion.el ends here

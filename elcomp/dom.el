;;; Dominators. -*- lexical-binding:t -*-

;;; Commentary:

;;; Code:

(require 'elcomp)
(require 'elcomp/back)

(cl-defun elcomp--first-processed-predecessor (bb)
  (maphash
   (lambda (pred _ignore)
     (if (elcomp--basic-block-immediate-dominator pred)
	 (cl-return-from elcomp--first-processed-predecessor pred)))
   (elcomp--basic-block-parents bb))
  (error "couldn't find processed predecessor in %S"
	 (elcomp--basic-block-number bb)))

(defun elcomp--predecessors (bb)
  (let ((result nil))
    (maphash
     (lambda (pred _ignore)
       (push pred result))
     (elcomp--basic-block-parents bb))
    result))

(defun elcomp--intersect (bb1 bb2 postorder-number)
  (let ((f1 (gethash bb1 postorder-number))
	(f2 (gethash bb2 postorder-number)))
    (while (not (eq f1 f2))
      (while (< f1 f2)
	(setf bb1 (elcomp--basic-block-immediate-dominator bb1))
	(setf f1 (gethash bb1 postorder-number)))
      (while (< f2 f1)
	(setf bb2 (elcomp--basic-block-immediate-dominator bb2))
	(setf f2 (gethash bb2 postorder-number))))
    bb1))

(defun elcomp--clear-dominators (compiler)
  ;; Clear out the old dominators.
  (elcomp--iterate-over-bbs
   compiler
   (lambda (bb)
     (setf (elcomp--basic-block-immediate-dominator bb) nil))))

(defun elcomp--compute-dominators (compiler)
  ;; Require back edges.
  (elcomp--require-back-edges compiler)
  (elcomp--clear-dominators compiler)

  (let ((nodes (elcomp--postorder compiler))
	reversed
	(postorder-number (make-hash-table)))

    ;; Perhaps POSTORDER-NUMBER should simply be an attribute on the
    ;; BB.
    (let ((i 0))
      (dolist (bb nodes)
	(puthash bb i postorder-number)
	(cl-incf i)))

    (setf reversed (delq (elcomp--entry-block compiler) (nreverse nodes)))
    (setf nodes nil)			; Paranoia.
    (setf (elcomp--basic-block-immediate-dominator
	   (elcomp--entry-block compiler))
	  (elcomp--entry-block compiler))

    (let ((changed t))
      (while changed
	(setf changed nil)
	(dolist (bb reversed)
	  (let ((new-idom (elcomp--first-processed-predecessor bb)))
	    (dolist (pred (elcomp--predecessors bb))
	      (unless (eq new-idom pred)
		(if (elcomp--basic-block-immediate-dominator pred)
		    (setf new-idom (elcomp--intersect pred new-idom
						      postorder-number)))))
	    (unless (eq new-idom
			(elcomp--basic-block-immediate-dominator bb))
	      (setf (elcomp--basic-block-immediate-dominator bb) new-idom)
	      (setf changed t))))))))

(provide 'elcomp/dom)

;;; dom.el ends here

;;;-*- Mode: Lisp; Package: CCL -*-
;;;
;;; Copyright 1994-2009 Clozure Associates
;;;
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.

;;; ppc-callback-support.lisp
;;;
;;; Support for PPC callbacks

(in-package "CCL")



;;; This is machine-dependent (it conses up a piece of "trampoline" code
;;; which calls a subprim in the lisp kernel.)
#-(and linuxppc-target poweropen-target)
(defun make-callback-trampoline (index &optional info)
  (declare (ignorable info))
  (macrolet ((ppc-lap-word (instruction-form)
               (uvref (uvref (compile nil `(lambda (&lap 0) (ppc-lap-function () ((?? 0)) ,instruction-form))) 0) #+ppc32-host 0 #+ppc64-host 1)))
    (let* ((subprim
	    #+eabi-target
	     #.(subprim-name->offset '.SPeabi-callback)
	     #-eabi-target
             #.(subprim-name->offset '.SPpoweropen-callback))
           (p (%allocate-callback-pointer 12)))
      (setf (%get-long p 0) (logior (ldb (byte 8 16) index)
                                    (ppc-lap-word (lis 11 ??)))   ; unboxed index
            (%get-long p 4) (logior (ldb (byte 16 0) index)
                                    (ppc-lap-word (ori 11 11 ??)))
                                   
	    (%get-long p 8) (logior subprim
                                    (ppc-lap-word (ba ??))))
      (ff-call (%kernel-import #.target::kernel-import-makedataexecutable) 
               :address p 
               :unsigned-fullword 12
               :void)
      p)))

;;; In the 64-bit LinuxPPC ABI, functions are "transfer vectors":
;;; two-word vectors that contain the entry point in the first word
;;; and a pointer to the global variables ("table of contents", or
;;; TOC) the function references in the second word.  We can use the
;;; TOC word in the transfer vector to store the callback index.
#+(and linuxppc-target poweropen-target)
(defun make-callback-trampoline (index &optional info)
  (declare (ignorable info))
  (let* ((p (%allocate-callback-pointer 16)))
    (setf (%%get-unsigned-longlong p 0) #.(subprim-name->offset '.SPpoweropen-callback)
          (%%get-unsigned-longlong p 8) index)
    p))


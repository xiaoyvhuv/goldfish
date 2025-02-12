;;  MIT License

;  Copyright guenchi (c) 2018 - 2019
;            Da Shen (c) 2024 - 2025
     
;  Permission is hereby granted, free of charge, to any person obtaining a copy
;  of this software and associated documentation files (the "Software"), to deal
;  in the Software without restriction, including without limitation the rights
;  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;  copies of the Software, and to permit persons to whom the Software is
;  furnished to do so, subject to the following conditions:
     
;  The above copyright notice and this permission notice shall be included in all
;  copies or substantial portions of the Software.
     
;  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;  SOFTWARE.

(define-library (liii json)
(import (liii chez) (liii alist) (liii list) (liii string))
(export 
  json-string-escape json-string-unescape string->json json->string
  json-ref json-ref*
  json-set json-set* json-push json-push* json-drop json-drop* json-reduce json-reduce*)
(begin

(define (json-string-escape str)
  (define (escape-char c)
    (case c
      ((#\") "\\\"")
      ((#\\) "\\\\")
      ((#\/) "\\/")
      ((#\backspace) "\\b")
      ((#\xc) "\\f")
      ((#\newline) "\\n")
      ((#\return) "\\r")
      ((#\tab) "\\t")
      (else (string c))))
        
  (let ((escaped (string-fold (lambda (ch result) (string-append result (escape-char ch))) "" str)))
    (string-append "\"" escaped "\"")))

(define (string-length-sum strings)
  (let loop ((o 0)
             (rest strings))
    (cond
     ((eq? '() rest) o)
     (else
      (loop (+ o (string-length (car rest)))
            (cdr rest))))))

(define (fast-string-list-append strings)
  (let* ((output-length (string-length-sum strings))
         (output (make-string output-length #\_))
         (fill 0))
    (let outer ((rest strings))
      (cond
       ((eq? '() rest) output)
       (else
        (let* ((s (car rest))
               (n (string-length s)))
          (let inner ((i 0))
            (cond ((= i n) 'done)
                  (else
                   (string-set! output fill (string-ref s i))
                   (set! fill (+ fill 1))
                   (inner (+ i 1))))))
        (outer (cdr rest)))))))

(define (handle-escape-char s end len)
  (let ((next-char (if (< (+ end 1) len)
                       (string-ref s (+ end 1))
                       #f)))
    (case next-char
      ((#\")
       (values "\"" (+ end 2)))
      ((#\\)
       (values "\\" (+ end 2)))
      ((#\/)
       (values "/" (+ end 2)))
      ((#\b)
       (values "\b" (+ end 2)))
      ((#\f)
       (values "\f" (+ end 2)))
      ((#\n)
       (values "\n" (+ end 2)))
      ((#\r)
       (values "\r" (+ end 2)))
      ((#\t)
       (values "\t" (+ end 2)))
      (else
       (values (string (string-ref s end) next-char) (+ end 2))))))

(define string->json
  (lambda (s)
    (read (open-input-string
      (let loop
        ((s s) (bgn 0) (end 0) (rst '()) (len (string-length s)) (quts? #f) (lst '(#t)))
        (cond
          ((and (= len 2) (string=? s "\"\""))
           "\"\"")
          ((= end len)
           (fast-string-list-append (reverse rst)))
          ((and quts? (char=? (string-ref s end) #\\))
           (let-values (((escaped-char new-end) (handle-escape-char s end len)))
             (loop s bgn new-end rst len quts? lst)))
          ((and quts? (not (char=? (string-ref s end) #\")))
           (loop s bgn (+ 1 end) rst len quts? lst))
          (else
            (case (string-ref s end)
              ((#\{)
               (loop s (+ 1 end) (+ 1 end) 
                 (cons 
                   (string-append 
                     (substring s bgn end) "((" ) rst) len quts? (cons #t lst)))
              ((#\})
               (loop s (+ 1 end) (+ 1 end) 
                 (cons
                   (string-append 
                     (substring s bgn end) "))") rst) len quts? (loose-cdr lst)))
              ((#\[)
               (loop s (+ 1 end) (+ 1 end) 
                  (cons
                    (string-append 
                      (substring s bgn end) "#(") rst) len quts? (cons #f lst)))
              ((#\])
               (loop s (+ 1 end) (+ 1 end) 
                 (cons 
                   (string-append 
                     (substring s bgn end) ")") rst) len quts? (loose-cdr lst)))
              ((#\:)
               (loop s (+ 1 end) (+ 1 end) 
                 (cons 
                   (string-append 
                     (substring s bgn end) " . ") rst) len quts? lst))
              ((#\,)
               (loop s (+ 1 end) (+ 1 end) 
                 (cons 
                   (string-append 
                     (substring s bgn end) 
                     (if (loose-car lst) ")(" " ")) rst) len quts? lst))
              ((#\")
               (loop s bgn (+ 1 end) rst len (not quts?) lst))
              (else
               (loop s bgn (+ 1 end) rst len quts? lst))))))))))

(define json->string
  (lambda (lst)
    (define f
      (lambda (x)
        (cond                           
          ((string? x) (json-string-escape x))                        
          ((number? x) (number->string x))                             
          ((symbol? x) (symbol->string x)))))
    (define c
      (lambda (x)
        (if (zero? x) "" ",")))
    (let l ((lst lst)(x (if (vector? lst) "[" "{")))
      (if (vector? lst)
        (string-append x 
          (let t ((len (vector-length lst))(n 0)(y ""))
            (if (< n len)
              (t len (+ n 1)
                (let ((k (vector-ref lst n)))
                  (if (atom? k)
                    (if (vector? k)
                      (l k (string-append y (c n) "["))
                      (string-append y (c n) (f k)))
                    (l k (string-append y (c n) "{")))))
              (string-append y "]"))))
        (let ((k (cdar lst)))
          (if (null? (cdr lst))
            (string-append x "\"" (caar lst) "\":"
              (cond
                ((list? k)(l k "{"))
                ((vector? k)(l k "["))
                (else (f k))) "}")
            (l (cdr lst)
              (cond 
                ((list? k)(string-append x "\"" (caar lst) "\":" (l k "{") ","))
                ((vector? k)(string-append x "\"" (caar lst) "\":" (l k "[") ","))
                (else (string-append x "\"" (caar lst) "\":" (f k) ","))))))))))

(define json-ref
  (lambda (x k)
    (define return
      (lambda (x)
        (if (symbol? x)
            (cond
              ((symbol=? x 'true) #t)
              ((symbol=? x 'false) #f)
              ((symbol=? x 'null) '())
              (else x))
            x)))
    (if (vector? x)
        (return (vector-ref x k))
        (let l ((x x) (k k))
          (if (null? x)
              '()
              (if (equal? (caar x) k)
                  (return (cdar x))
                  (l (cdr x) k)))))))

(define (json-ref* j . keys)
  (let loop ((expr j) (keys keys))
    (if (null? keys)
        expr
        (loop (json-ref expr (car keys)) (cdr keys)))))

(define json-set
  (lambda (x v p)
    (let ((x x) (v v) (p (if (procedure? p) p (lambda (x) p))))
      (if (vector? x)
          (list->vector
            (cond 
              ((boolean? v)
                (if v
                  (let l ((x (vector->alist x))(p p))
                    (if (null? x)
                      '()
                      (cons (p (cdar x)) (l (cdr x) p))))))
              ((procedure? v)
                (let l ((x (vector->alist x))(v v)(p p))
                  (if (null? x)
                    '()
                    (if (v (caar x))
                      (cons (p (cdar x)) (l (cdr x) v p))
                      (cons (cdar x) (l (cdr x) v p))))))
              (else
                (let l ((x (vector->alist x))(v v)(p p))
                  (if (null? x)
                    '()
                    (if (equal? (caar x) v)
                      (cons (p (cdar x)) (l (cdr x) v p))
                      (cons (cdar x) (l (cdr x) v p))))))))
          (cond
            ((boolean? v)
              (if v
                (let l ((x x)(p p))
                  (if (null? x)
                    '()
                    (cons (cons (caar x) (p (cdar x)))(l (cdr x) p))))))
            ((procedure? v)
              (let l ((x x)(v v)(p p))
                (if (null? x)
                  '()
                  (if (v (caar x))
                    (cons (cons (caar x) (p (cdar x)))(l (cdr x) v p))
                    (cons (car x) (l (cdr x) v p))))))
            (else
              (let l ((x x)(v v)(p p))
                (if (null? x)
                  '()
                  (if (equal? (caar x) v)
                    (cons (cons v (p (cdar x)))(l (cdr x) v p))
                    (cons (car x) (l (cdr x) v p)))))))))))

(define (json-set* json k0 k1_or_v . ks_and_v)
  (if (null? ks_and_v)
      (json-set json k0 k1_or_v)
      (json-set json k0
        (lambda (x)
          (apply json-set* (cons x (cons k1_or_v ks_and_v)))))))

(define (json-push x k v)
  (if (vector? x)
      (if (= (vector-length x) 0)
          (vector v)
          (list->vector
            (let l ((x (vector->alist x)) (k k) (v v) (b #f))
              (if (null? x)
                  (if b '() (cons v '()))
                  (if (equal? (caar x) k)
                      (cons v (cons (cdar x) (l (cdr x) k v #t)))
                      (cons (cdar x) (l (cdr x) k v b)))))))
      (cons (cons k v) x)))

(define (json-push* json k0 v0 . rest)
  (if (null? rest)
      (json-push json k0 v0)
      (json-set json k0
        (lambda (x) (apply json-push* (cons x (cons v0 rest)))))))

(define json-drop
  (lambda (x v)
    (if (vector? x)
        (if (zero? (vector-length x))
            x
            (list->vector
             (cond
               ((procedure? v)
                (let l ((x (vector->alist x)) (v v))
                  (if (null? x)
                      '()
                      (if (v (caar x))
                          (l (cdr x) v)
                          (cons (cdar x) (l (cdr x) v))))))
               (else
                (let l ((x (vector->alist x)) (v v))
                  (if (null? x)
                      '()
                      (if (equal? (caar x) v)
                          (l (cdr x) v)
                          (cons (cdar x) (l (cdr x) v)))))))))
        (cond
          ((procedure? v)
           (let l ((x x) (v v))
             (if (null? x)
                 '()
                 (if (v (caar x))
                     (l (cdr x) v)
                     (cons (car x) (l (cdr x) v))))))
          (else
           (let l ((x x) (v v))
             (if (null? x)
                 '()
                 (if (equal? (caar x) v)
                     (l (cdr x) v)
                     (cons (car x) (l (cdr x) v))))))))))

(define json-drop*
  (lambda (json key . rest)
    (if (null? rest)
        (json-drop json key)
        (json-set json key
                  (lambda (x) (apply json-drop* (cons x rest)))))))

(define json-reduce
  (lambda (x v p)
    (if (vector? x)
        (list->vector
         (cond
           ((boolean? v)
            (if v
                (let l ((x (vector->alist x)) (p p))
                  (if (null? x)
                      '()
                      (cons (p (caar x) (cdar x)) (l (cdr x) p))))
                x))
           ((procedure? v)
            (let l ((x (vector->alist x)) (v v) (p p))
              (if (null? x)
                  '()
                  (if (v (caar x))
                      (cons (p (caar x) (cdar x)) (l (cdr x) v p))
                      (cons (cdar x) (l (cdr x) v p))))))
           (else
            (let l ((x (vector->alist x)) (v v) (p p))
              (if (null? x)
                  '()
                  (if (equal? (caar x) v)
                      (cons (p (caar x) (cdar x)) (l (cdr x) v p))
                      (cons (cdar x) (l (cdr x) v p))))))))
        (cond
          ((boolean? v)
           (if v
               (let l ((x x) (p p))
                 (if (null? x)
                     '()
                     (cons (cons (caar x) (p (caar x) (cdar x))) (l (cdr x) p))))
               x))
          ((procedure? v)
           (let l ((x x) (v v) (p p))
             (if (null? x)
                 '()
                 (if (v (caar x))
                     (cons (cons (caar x) (p (caar x) (cdar x))) (l (cdr x) v p))
                     (cons (car x) (l (cdr x) v p))))))
          (else
           (let l ((x x) (v v) (p p))
             (if (null? x)
                 '()
                 (if (equal? (caar x) v)
                     (cons (cons v (p v (cdar x))) (l (cdr x) v p))
                     (cons (car x) (l (cdr x) v p))))))))))

(define (json-reduce* j v1 v2 . rest)
  (cond
    ((null? rest) (json-reduce j v1 v2))
    ((length=? 1 rest)
     (json-reduce j v1
       (lambda (x y)
         (let* ((new-v1 v2)
                (p (last rest)))
          (json-reduce y new-v1
                       (lambda (n m) (p (list x n) m)))))))
    (else
     (json-reduce j v1
       (lambda (x y)
         (let* ((new-v1 v2)
                (p (last rest)))
          (apply json-reduce*
                 (append (cons y (cons new-v1 (drop-right rest 1)))
                         (list (lambda (n m) (p (cons x n) m)))))))))))

) ; end of begin
) ; end of define-library


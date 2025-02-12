(set! *load-path* (cons "http" *load-path*))
(set! *load-path* (cons "json" *load-path*))

(import (liii http)
        (liii json)
        (liii list)
        (liii os)
        (liii string)
        (liii path)
        (liii case))

(define (read-and-clean-file file-path)
  (string-trim-right (path-read-text file-path) #\newline))

(define (load-silicon-cloud-api-key)
  (let* ((home (if (os-windows?)
                   (getenv "USERPROFILE") ; Windows 使用 USERPROFILE
                   (getenv "HOME")))      ; Unix/Linux 使用 HOME
         (file-path (string-append home (string (os-sep)) ".silicon_cloud")))
    (if (file-exists? file-path)          ; 直接判断文件是否存在
        (read-and-clean-file file-path)
        "请填入硅基流动的API密钥")))

(define-case-class message
  ((role string?)
   (content string?))

  (define (%to-json)
    `(("role" . ,role) ("content" . ,content))))

(define (message? obj)
  (obj :is-instance-of 'message))

(define-case-class payload
  ((messages vector? #()))
  
  (define (%to-json)
    `(("model" . "deepseek-ai/DeepSeek-V2.5")
     ("messages" . ,(vector-map (lambda (x) (x :to-json)) messages))
     ("max_tokens" . 512)))
  
  (define (%to-json-string)
    (json->string (%to-json)))
  
  (typed-define (%append (msg message?))
    (payload :messages (vector-append messages (vector msg)))))

(define headers
  `(
     ("Authorization" . ,(string-append "Bearer " (load-silicon-cloud-api-key)))
     ("Content-Type" . "application/json")
   )
)

(define (chat payload)
  (let* ((r (http-post "https://api.siliconflow.cn/v1/chat/completions"
            :data (payload :to-json-string)
            :headers headers)))
    (if (http-ok? r)
        (r 'text)
        (r 'status-code))))

(define questions
  #("唐宋八大家是哪八位（简短回答）"
    "请按照顺序返回上一个回答中的第五位"
    "用双引号引用上一个问题的回答（包含标点符号），并告诉我一共多少个汉字？"
    "介绍他的生平和作品（简短回答）"))

(let loop ((i 0) (p (payload #())) (tokens 0))
  (if (< i (length questions))
      (let* ((q (p :append (message "user" (questions i))))
             (r (chat q))
             (j (string->json r))
             (a (json-ref* j "choices" 0 "message" "content")))
          (display* "payload: " (q :to-json-string))
          (newline)
          (newline)
          (display* "Q: " (questions i) "\n")
          (display* "A: " a "\n")
          (newline)
          (loop (+ i 1)
                (q :append (message "assistant" a))
                (+ tokens (json-ref* j "usage" "total_tokens"))))
      (display* "Total tokens: " tokens)))


#lang racket

(require "mk.rkt"
         "helpers.rkt")

(provide substo)

; categories of expressions for free-vars
(define unary-ops '(add1 car cdr same))
(define binary-ops '(cons the))
(define trinary-ops '(ind-= =))
(define dep-binders '(Σ Π))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; free variables in an expression

(defrel (free-unary exp vs)
  (fresh (tag e)
    (== exp `(,tag ,e))
    (membero tag unary-ops)
    (free-vars e vs)))

(defrel (free-binary exp vs)
  (fresh (tag e₁ e₂ vs₁ vs₂)
    (== exp `(,tag ,e₁ ,e₂))
    (membero tag binary-ops)
    (free-vars e₁ vs₁)
    (free-vars e₂ vs₂)
    (uniono vs₁ vs₂ vs)))

(defrel (free-trinary exp vs)
  (fresh (tag e₁ e₂ e₃ vs₁ vs₂ vs₃ vs1)
    (== exp `(,tag ,e₁ ,e₂ ,e₃))
    (free-vars e₁ vs₁)
    (free-vars e₂ vs₂)
    (free-vars e₃ vs₃)
    (uniono vs₁ vs₂ vs1)
    (uniono vs1 vs₃ vs)))

(defrel (free-dep-binder exp vs)
  (fresh (tag x T₁ T₂ vs₁ vs₂ vs₂f)
    (== exp `(,tag ((,x ,T₁)) ,T₂))
    (membero tag dep-binders)
    (free-vars T₁ vs₁)
    (free-vars T₂ vs₂)
    (removo x vs₂ vs₂f)
    (uniono vs₁ vs₂f vs)))

(defrel (free-lambda exp vs)
  (fresh (x b vs^)
    (== exp `(λ (,x) ,b))
    (free-vars b vs^)
    (removo x vs^ vs)))

(defrel (free-quote exp vs)
  (fresh (s)
    (== exp `(quote ,s))
    (symbolo s)
    (== vs '())))

(defrel (free-ind-Nat exp vs)
  (fresh (t m b s vt vm vb vst v1 v2)
    (== exp `(ind-Nat ,t ,m ,b ,s))
    (free-vars t vt)
    (free-vars m vm)
    (free-vars b vb)
    (free-vars s vst)
    (uniono vt vm v1)
    (uniono v1 vb v2)
    (uniono v2 vst vs)))

(defrel (free-app exp vs)
  (fresh (f arg f-vs arg-vs)
    (== exp `(,f ,arg))
    (not-reserved-fn f)
    (free-vars f f-vs)
    (free-vars arg arg-vs)
    (uniono f-vs arg-vs vs)))

(defrel (free-vars exp vs)
  (conde
    [(not-reserved-symbol exp) (== vs `(,exp))]
    [(reserved-symbol exp) (== vs '())]
    [(free-dep-binder exp vs)]
    [(free-lambda exp vs)]
    [(free-quote exp vs)]
    [(free-ind-Nat exp vs)]
    [(free-unary exp vs)]
    [(free-binary exp vs)]
    [(free-trinary exp vs)]
    [(free-app exp vs)]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; capture-avoiding substitution

;; helpers
(defrel (avoid-capture x y z a e eᵣ)
  (conde
    [(== y x) (== e eᵣ) (== z y)]
    [(=/= y x)
     (fresh (vs-e vs-a)
       (free-vars e vs-e)
       (free-vars a vs-a)
       (conde
         [(conde
            [(not-membero x vs-e)]
            [(not-membero y vs-a)])
          (== z y)
          (substo x a e eᵣ)]
         [(membero x vs-e)
          (membero y vs-a)
          (fresh (fr e-new)
            (fresh-name fr)
            (== z fr)
            (substo y fr e e-new)
            (substo x a e-new eᵣ))]))]))

(defrel (subst-unary x a exp o)
  (fresh (tag e eᵣ)
    (== exp `(,tag ,e))
    (membero tag unary-ops)
    (== o `(,tag ,eᵣ))
    (substo x a e eᵣ)))

(defrel (subst-binary x a exp o)
  (fresh (tag e₁ e₂ e₁ᵣ e₂ᵣ)
    (== exp `(,tag ,e₁ ,e₂))
    (== o `(the ,e₁ᵣ ,e₂ᵣ))
    (substo x a e₁ e₁ᵣ)
    (substo x a e₂ e₂ᵣ)))

(defrel (subst-trinary x a exp o)
  (fresh (tag e₁ e₂ e₃ e₁ᵣ e₂ᵣ e₃ᵣ)
    (== exp `(,tag ,e₁ ,e₂ ,e₃))
    (membero tag trinary-ops)
    (== o `(,tag ,e₁ᵣ ,e₂ᵣ ,e₃ᵣ))
    (substo x a e₁ e₁ᵣ)
    (substo x a e₂ e₂ᵣ)
    (substo x a e₃ e₃ᵣ)))

(defrel (subst-atom exp o)
  (fresh (s)
    (symbolo s)
    (== exp `(quote ,s))
    (== exp o)))

(defrel (subst-app x a exp o)
  (fresh (f arg f^ arg^)
    (== exp `(,f ,arg))
    (not-reserved-fn f)
    (== o `(,f^ ,arg^))
    (substo x a f f^)
    (substo x a arg arg^)))

(defrel (subst-ind-Nat x a exp o)
  (fresh (t m b s tᵣ mᵣ bᵣ sᵣ)
    (== exp `(ind-Nat ,t ,m ,b ,s))
    (== o `(ind-Nat ,tᵣ ,mᵣ ,bᵣ ,sᵣ))
    (substo x a t tᵣ)
    (substo x a m mᵣ)
    (substo x a b bᵣ)
    (substo x a s sᵣ)))

(defrel (subst-dep x a exp o)
  (fresh (tag y T₁ T₁ᵣ T₂ z T₂ᵣ)
    (== exp `(,tag ([,y ,T₁]) ,T₂))
    (membero tag dep-binders)
    (== o `(,tag ([,z ,T₁ᵣ]) ,T₂ᵣ))
    (substo x a T₁ T₁ᵣ)
    (avoid-capture x y z a T₂ T₂ᵣ)))

(defrel (subst-lambda x a exp o)
  (fresh (y z b bᵣ b-vars a-vars)
    (== exp `(λ (,y) ,b))
    (== o `(λ (,z) ,bᵣ))
    (avoid-capture x y z a b bᵣ)))

(defrel (substo x a exp o)
  (conde
    [(== exp x) (== o a)]
    [(symbolo exp) (=/= exp x) (== exp o)]
    [(subst-atom exp o)]
    [(subst-lambda x a exp o)]
    [(subst-dep x a exp o)]
    [(subst-app x a exp o)]
    [(subst-unary x a exp o)]
    [(subst-binary x a exp o)]
    [(subst-trinary x a exp o)]
    [(subst-ind-Nat x a exp o)]))

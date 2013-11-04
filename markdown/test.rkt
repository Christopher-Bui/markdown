#lang at-exp racket

(require rackjure/threading
         "parse.rkt"
         "display-xexpr.rkt")

(module+ test
  (require rackunit racket/runtime-path)
  (define-syntax-rule (check-md x y)
    (check-equal? (parse-markdown x) y)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Test: Compare to static file.

(define test-footnote-prefix 'unit-test) ;fixed, not from (gensym)

(module+ test
  (define-runtime-path test.md "test/test.md")
  (define xs (with-input-from-file test.md
               (thunk (read-markdown test-footnote-prefix))))

  ;; Reference file. Update this periodically as needed.
  (define-runtime-path test.html "test/test.html")

  (define test.out.html (build-path (find-system-path 'temp-dir)
                                    "test.out.html"))

  (with-output-to-file test.out.html #:exists 'replace
                       (lambda ()
                         (display "<!DOCTYPE html>")
                         (~> `(html (head () (meta ([charset "utf-8"])))
                                    (body () ,@xs))
                             display-xexpr)))

  (check-equal? (system/exit-code (~a "diff " test.html " " test.out.html))
                0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Blockquote

(module+ test
  (check-md @~a{> Foo
                > Foo
                >
                > Foo
                > Foo
                }
            '((blockquote () (p () "Foo Foo") (p () "Foo Foo")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; List

(module+ test
  ;; Loose
  (check-md @~a{- One.
                
                - Two.
                
                }
            '((ul () (li () (p () "One."))
                  (li () (p () "Two.")))))
  ;; Tight
  (check-md @~a{- One.
                - Two.
                }
           '((ul () (li () "One.")
                 (li () "Two."))))
  ;; Indented < 4 spaces, loose
  (check-md @~a{  - One.
                  
                  - Two.
                  
                  }
            '((ul () (li () (p () "One."))
                  (li () (p () "Two.")))))
  ;; Ordered
  (check-md @~a{1. One.
                
                2. Two.
                
                }
            '((ol () (li () (p () "One."))
                  (li () (p () "Two."))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Footnote definition

(module+ test
  (let ()
    (define prefix "foo") ;; fixed footnote prefix, not gensym
    (check-equal?
     (parse-markdown @~a{Footnote use[^1].
                         
                         [^1]: The first paragraph of the definition.
                         
                             Paragraph two of the definition.
                         
                             > A blockquote with
                             > multiple lines.

                                 a code block
                                 here
                             
                             A final paragraph.
                         
                         Not part of defn.
                         
                         }
                     prefix)
     `((p () "Footnote use"
          (sup () (a ([href "#foo-footnote-1-definition"]
                      [name "foo-footnote-1-return"]) "1")) ".")
       (div ([id "foo-footnote-1-definition"]
             [class "footnote-definition"])
            (p () "1: The first paragraph of the definition.")
            (p () "Paragraph two of the definition.")
            (blockquote () (p () "A blockquote with multiple lines."))
            (pre () "a code block\n here")
            (p () "A final paragraph. "
               (a ([href "#foo-footnote-1-return"]) "↩")))
       (p () "Not part of defn.")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Emphasis and strong

(module+ test
  ;; All 8 permutations
  (define s/e '((strong () "Bold " (em () "italic") " bold")))
  (check-md "**Bold *italic* bold**" s/e)
  (check-md "**Bold _italic_ bold**" s/e)
  (check-md "__Bold _italic_ bold__" s/e)
  (check-md "__Bold *italic* bold__" s/e)

  (define e/s '((em () "Italic " (strong () "bold") " italic")))
  (check-md "*Italic **bold** italic*" e/s)
  (check-md "*Italic __bold__ italic*" e/s)
  (check-md "_Italic __bold__ italic_" e/s)
  (check-md "_Italic **bold** italic_" e/s)

  ;; More teste
  (check-md "no __YES__ no __YES__"
                '("no " (strong () "YES") " no " (strong () "YES")))
  (check-md "no **YES** no **YES**"
                '("no " (strong () "YES") " no " (strong () "YES")))
  (check-md "** no no **"
                '("** no no **"))
  (check-md "no ____ no no"
                '("no ____ no no"))
  (check-md "__Bold with `code` inside it.__"
                '((strong () "Bold with " (code () "code") " inside it.")))

  (check-md "no _YES_ no _YES_"
                '("no " (em () "YES") " no " (em () "YES")))
  (check-md "no *YES* no *YES*"
                '("no " (em () "YES") " no " (em () "YES")))
  (check-md "no_no_no"
                '("no_no_no"))
  ;; (check-md "* no no *"
  ;;               '("* no no *"))
  (check-md "** no no **"
                '("** no no **"))
  ;; (check-md "_YES_ no no_no _YES_YES_ _YES YES_"
  ;;               '((em () "YES") " no no_no "
  ;;                 (em () "YES_YES") " " (em () "YES YES")))
  (check-md "\\_text surrounded by literal underlines\\_"
                '("_text surrounded by literal underlines_"))
  (check-md "\\*text surrounded by literal asterisks\\*"
                '("*text surrounded by literal asterisks*")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Smart dashes

(module+ test
  (check-md "This -- section -- is here and this--is--here---and this."
            '("This " ndash " section " ndash " is here and this" ndash "is"
              ndash "here" mdash "and this.")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Smart quotes

(module+ test
  (check-md "She said, \"Why\"?"
            '("She said, " ldquo "Why" rdquo "?"))
  (check-md "She said, \"Why?\""
            '("She said, " ldquo "Why?" rdquo))
  (check-md "She said, \"Oh, _really_\"?"
            '("She said, " ldquo "Oh, " (em () "really") rdquo "?"))
  (check-md "She said, \"Oh, _really_?\""
                '("She said, " ldquo "Oh, " (em () "really") "?" rdquo))

  (check-md "She said, 'Why'?"
            '("She said, " lsquo "Why" rsquo "?"))
  (check-md "She said, 'Why?'"
            '("She said, " lsquo "Why?" rsquo))
  (check-md "She said, 'Oh, _really_'?"
            '("She said, " lsquo "Oh, " (em () "really") rsquo "?"))
  (check-md "She said, 'Oh, _really_?'"
            '("She said, " lsquo "Oh, " (em () "really") "?" rsquo))
  ;; Pairs of apostrophes treated as such
  (check-md "It's just Gus' style, he's 6' tall."
            '("It" rsquo "s just Gus" rsquo " style, he" rsquo "s 6'" " tall."))
  ;; Weird cases
  ;; (check-md "\"\"" '(ldquo rdquo))
  ;; (check-md "''" '(lsquo rsquo))
  ;; (check-md " ' ' " '(" " lsquo " " rsquo " "))
  ;; (check-md "'''" '("'" lsquo rsquo))

  ;; Check not too greedy match
  (check-md "And 'this' and 'this' and."
            '("And " lsquo "this" rsquo " and " lsquo "this" rsquo " and."))
  (check-md "And \"this\" and \"this\" and."
            '("And " ldquo "this" rdquo " and " ldquo "this" rdquo " and."))
  ;; Check nested quotes, American style
  (check-md "John said, \"She replied, 'John, you lug.'\""
            '("John said, " ldquo "She replied, " lsquo "John, you lug." rsquo rdquo))
  (check-md "John said, \"She replied, 'John, you lug'.\""
            '("John said, " ldquo "She replied, " lsquo "John, you lug" rsquo "." rdquo))
  ;; Check nested quotes, British style
  (check-md "John said, 'She replied, \"John, you lug.\"'"
            '("John said, " lsquo "She replied, " ldquo "John, you lug." rdquo rsquo))
  (check-md "John said, 'She replied, \"John, you lug\".'"
            '("John said, " lsquo "She replied, " ldquo "John, you lug" rdquo "." rsquo))
  ;; Yeah, sorry. Not going to deal with 3 levels, as in this test:
  ;; (parse-markdown "Hey, \"Outer 'middle \"inner\" middle' outer\" there"))

  ;; Check interaction with other elements
  (check-md "Some `code with 'symbol`"
            '("Some " (code () "code with 'symbol")))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Regression tests

(module+ test
  ;; https://github.com/greghendershott/markdown/issues/6
  (check-md "_italic with `code` inside it_"
            '((em () "italic with " (code () "code") " inside it")))
  (check-md "_italic with **bold** inside it_"
            '((em () "italic with " (strong () "bold") " inside it")))
  ;; https://github.com/greghendershott/markdown/issues/6
  (check-md "**bold with `code` inside it**"
            '((strong () "bold with " (code () "code") " inside it")))
  (check-md "**bold with _italic_ inside it**"
            '((strong () "bold with " (em () "italic") " inside it")))
  ;; https://github.com/greghendershott/markdown/issues/8
  (check-md "And: [Racket \\[the language\\]](http://www.racket-lang.org/)."
            '("And: "
              (a ([href "http://www.racket-lang.org/"])
                 "Racket [the language]")
              "."))
  (check-md "And: [Racket [the language]](http://www.racket-lang.org/)."
            '("And: "
              (a ([href "http://www.racket-lang.org/"])
                 "Racket [the language]")
              "."))
  (check-md "\\[Not a link\\](nope)"
            '("[Not a link](nope)"))
  ;; https://github.com/greghendershott/markdown/issues/5
  (check-md "[![foo](foo.jpg)](foo.html)"
            '((a ([href "foo.html"])
                 (img ([src "foo.jpg"]
                       [alt "foo"]
                       [title ""])))))
  ;; https://github.com/greghendershott/markdown/issues/5
  (check-md "[<img src=\"foo.jpg\" />](foo.html)"
            '((a ([href "foo.html"])
                 (img ([src "foo.jpg"])))))
  ;; https://github.com/greghendershott/markdown/issues/12
  (check-md "```\ncode block\n```\n<!-- more -->\n"
            '((pre () "code block") (!HTML-COMMENT () " more")))
  ;; https://github.com/greghendershott/markdown/issues/10
  (check-md @~a{These here
                -- should be dashes
                }
            '("These here " ndash " should be dashes"))
  (check-md "---\n"
            '((hr ())))
  (check-md "---hey ho"
            '(mdash "hey ho"))
  ;; https://github.com/greghendershott/markdown/issues/4
  (check-md @~a{    * blah blah
                    * blah blah
                    * blah blah
                
                }
            '((pre () "* blah blah\n* blah blah\n* blah blah")))
  (check-md "** no no **"
            '("** no no **"))
  (check-md "_ no no _"
            '("_ no no _"))
  ;; HTML vs. auto-links: Fight! (Not a specific regression test.)
  (check-md "<http://www.example.com/>"
            '((a ([href "http://www.example.com/"])
                 "http://www.example.com/")))
  (check-md "<img src='foo' />\n"
            '((img ((src "foo")))))
  ;; Bold and italic including nesting. (Not a specific regression test.)
  ;; Note the two spaces at each EOL are intentional!
  (check-md (string-join
             '("_Italic_.  "
               "*Italic*.  "
               "__Bold__.  "
               "**Bold**.  "
               "**Bold with _italic_ inside it**.  "
               "_Italic with **bold** inside it_.  "
               "Should be no ____ italics or bold on this line.  "
               "`I am code`.  "
               )
             "\n")
            '((em () "Italic") "." (br ())
              (em () "Italic") "." (br ())
              (strong () "Bold") "." (br ())
              (strong ()"Bold") "." (br ())
              (strong () "Bold with " (em () "italic") " inside it") "." (br ())
              (em () "Italic with " (strong () "bold") " inside it") "." (br ())
              "Should be no ____ italics or bold on this line." (br ())
              (code () "I am code") "." (br ())))
  ;; https://github.com/greghendershott/markdown/issues/14
  (check-md @~a{Here's a [reflink with 'quotes' in it][].
                
                [reflink with 'quotes' in it]: www.example.com
                }
            '((p ()
                 "Here" rsquo "s a "
                 (a ([href "www.example.com"])
                    "reflink with " lsquo "quotes" rsquo " in it") ".")))
  ;; https://github.com/greghendershott/markdown/issues/15
  (check-md "## Heading **with** _formatting_\n"
            '((h2 () "Heading " (strong () "with") " " (em () "formatting"))))
  ;; https://github.com/greghendershott/markdown/issues/16
  (check-md "**Bold** at line start shouldn't be bullet list.\n\n"
            '((p () (strong () "Bold") " at line start shouldn" rsquo "t be bullet list.")))
  ;; https://github.com/greghendershott/markdown/issues/16
  (check-md "1.23 at line start shouldn't be numbered list.\n\n"
            '((p () "1.23 at line start shouldn" rsquo "t be numbered list.")))
  ;; https://github.com/greghendershott/markdown/issues/18
  (check-md "Blah blah [label](http://www.example.com/two--hyphens.html)."
            '("Blah blah "
              (a ([href "http://www.example.com/two--hyphens.html"])
                 "label")
              "."))
  (check-md "Blah blah ![label](http://www.example.com/two--hyphens.html)."
            '("Blah blah "
              (img ([src "http://www.example.com/two--hyphens.html"]
                    [alt "label"]
                    [title ""]))
              "."))
  ;; https://github.com/greghendershott/markdown/issues/21
  (check-md "<pre>1\n2\n3</pre>"
            '((pre () "1\n2\n3")))
  )
! Copyright (C) 2008, 2009 Doug Coleman, Daniel Ehrenberg.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors kernel math math.order words combinators locals
ascii unicode.categories combinators.short-circuit sequences
fry macros arrays assocs sets classes mirrors ;
IN: regexp.classes

SINGLETONS: any-char any-char-no-nl
letter-class LETTER-class Letter-class digit-class
alpha-class non-newline-blank-class
ascii-class punctuation-class java-printable-class blank-class
control-character-class hex-digit-class java-blank-class c-identifier-class
unmatchable-class terminator-class word-boundary-class ;

SINGLETONS: beginning-of-input ^ end-of-input $ end-of-file word-break ;

TUPLE: range from to ;
C: <range> range

GENERIC: class-member? ( obj class -- ? )

M: t class-member? ( obj class -- ? ) 2drop t ;

M: integer class-member? ( obj class -- ? ) = ;

M: range class-member? ( obj class -- ? )
    [ from>> ] [ to>> ] bi between? ;

M: any-char class-member? ( obj class -- ? )
    2drop t ;

M: any-char-no-nl class-member? ( obj class -- ? )
    drop CHAR: \n = not ;

M: letter-class class-member? ( obj class -- ? )
    drop letter? ;
            
M: LETTER-class class-member? ( obj class -- ? )
    drop LETTER? ;

M: Letter-class class-member? ( obj class -- ? )
    drop Letter? ;

M: ascii-class class-member? ( obj class -- ? )
    drop ascii? ;

M: digit-class class-member? ( obj class -- ? )
    drop digit? ;

: c-identifier-char? ( ch -- ? )
    { [ alpha? ] [ CHAR: _ = ] } 1|| ;

M: c-identifier-class class-member? ( obj class -- ? )
    drop c-identifier-char? ;

M: alpha-class class-member? ( obj class -- ? )
    drop alpha? ;

: punct? ( ch -- ? )
    "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~" member? ;

M: punctuation-class class-member? ( obj class -- ? )
    drop punct? ;

: java-printable? ( ch -- ? )
    { [ alpha? ] [ punct? ] } 1|| ;

M: java-printable-class class-member? ( obj class -- ? )
    drop java-printable? ;

M: non-newline-blank-class class-member? ( obj class -- ? )
    drop { [ blank? ] [ CHAR: \n = not ] } 1&& ;

M: control-character-class class-member? ( obj class -- ? )
    drop control? ;

: hex-digit? ( ch -- ? )
    {
        [ CHAR: A CHAR: F between? ]
        [ CHAR: a CHAR: f between? ]
        [ CHAR: 0 CHAR: 9 between? ]
    } 1|| ;

M: hex-digit-class class-member? ( obj class -- ? )
    drop hex-digit? ;

: java-blank? ( ch -- ? )
    {
        CHAR: \s CHAR: \t CHAR: \n
        HEX: b HEX: 7 CHAR: \r
    } member? ;

M: java-blank-class class-member? ( obj class -- ? )
    drop java-blank? ;

M: unmatchable-class class-member? ( obj class -- ? )
    2drop f ;

M: terminator-class class-member? ( obj class -- ? )
    drop "\r\n\u000085\u002029\u002028" member? ;

M: ^ class-member? ( obj class -- ? )
    2drop f ;

M: $ class-member? ( obj class -- ? )
    2drop f ;

M: f class-member? 2drop f ;

TUPLE: primitive-class class ;
C: <primitive-class> primitive-class

TUPLE: not-class class ;

PREDICATE: not-integer < not-class class>> integer? ;
PREDICATE: not-primitive < not-class class>> primitive-class? ;

M: not-class class-member?
    class>> class-member? not ;

TUPLE: or-class seq ;

M: or-class class-member?
    seq>> [ class-member? ] with any? ;

TUPLE: and-class seq ;

M: and-class class-member?
    seq>> [ class-member? ] with all? ;

DEFER: substitute

: flatten ( seq class -- newseq )
    '[ dup _ instance? [ seq>> ] [ 1array ] if ] map concat ; inline

:: seq>instance ( seq empty class -- instance )
    seq length {
        { 0 [ empty ] }
        { 1 [ seq first ] }
        [ drop class new seq { } like >>seq ]
    } case ; inline

TUPLE: class-partition integers not-integers primitives not-primitives and or other ;

: partition-classes ( seq -- class-partition )
    prune
    [ integer? ] partition
    [ not-integer? ] partition
    [ primitive-class? ] partition ! extend primitive-class to epsilon tags
    [ not-primitive? ] partition
    [ and-class? ] partition
    [ or-class? ] partition
    class-partition boa ;

: class-partition>seq ( class-partition -- seq )
    make-mirror values concat ;

: repartition ( partition -- partition' )
    ! This could be made more efficient; only and and or are effected
    class-partition>seq partition-classes ;

: filter-not-integers ( partition -- partition' )
    dup
    [ primitives>> ] [ not-primitives>> ] [ or>> ] tri
    3append and-class boa
    '[ [ class>> _ class-member? ] filter ] change-not-integers ;

: answer-ors ( partition -- partition' )
    dup [ not-integers>> ] [ not-primitives>> ] [ primitives>> ] tri 3append
    '[ [ _ [ t substitute ] each ] map ] change-or ;

: contradiction? ( partition -- ? )
    {
        [ [ primitives>> ] [ not-primitives>> ] bi intersects? ]
        [ other>> f swap member? ]
    } 1|| ;

: make-and-class ( partition -- and-class )
    answer-ors repartition
    [ t swap remove ] change-other
    dup contradiction?
    [ drop f ]
    [ filter-not-integers class-partition>seq prune t and-class seq>instance ] if ;

: <and-class> ( seq -- class )
    dup and-class flatten partition-classes
    dup integers>> length {
        { 0 [ nip make-and-class ] }
        { 1 [ integers>> first [ '[ _ swap class-member? ] all? ] keep and ] }
        [ 3drop f ]
    } case ;

: filter-integers ( partition -- partition' )
    dup
    [ primitives>> ] [ not-primitives>> ] [ and>> ] tri
    3append or-class boa
    '[ [ _ class-member? not ] filter ] change-integers ;

: answer-ands ( partition -- partition' )
    dup [ integers>> ] [ not-primitives>> ] [ primitives>> ] tri 3append
    '[ [ _ [ f substitute ] each ] map ] change-and ;

: tautology? ( partition -- ? )
    {
        [ [ primitives>> ] [ not-primitives>> ] bi intersects? ]
        [ other>> t swap member? ]
    } 1|| ;

: make-or-class ( partition -- and-class )
    answer-ands repartition
    [ f swap remove ] change-other
    dup tautology?
    [ drop t ]
    [ filter-integers class-partition>seq prune f or-class seq>instance ] if ;

: <or-class> ( seq -- class )
    dup or-class flatten partition-classes
    dup not-integers>> length {
        { 0 [ nip make-or-class ] }
        { 1 [ not-integers>> first [ class>> '[ _ swap class-member? ] any? ] keep or ] }
        [ 3drop t ]
    } case ;

GENERIC: <not-class> ( class -- inverse )

M: object <not-class>
    not-class boa ;

M: not-class <not-class>
    class>> ;

M: and-class <not-class>
    seq>> [ <not-class> ] map <or-class> ;

M: or-class <not-class>
    seq>> [ <not-class> ] map <and-class> ;

M: t <not-class> drop f ;
M: f <not-class> drop t ;

M: primitive-class class-member?
    class>> class-member? ;

UNION: class primitive-class not-class or-class and-class range ;

TUPLE: condition question yes no ;
C: <condition> condition

GENERIC# answer 2 ( class from to -- new-class )

M:: object answer ( class from to -- new-class )
    class from = to class ? ;

: replace-compound ( class from to -- seq )
    [ seq>> ] 2dip '[ _ _ answer ] map ;

M: and-class answer
    replace-compound <and-class> ;

M: or-class answer
    replace-compound <or-class> ;

M: not-class answer
    [ class>> ] 2dip answer <not-class> ;

GENERIC# substitute 1 ( class from to -- new-class )
M: object substitute answer ;
M: not-class substitute [ <not-class> ] bi@ answer ;

: assoc-answer ( table question answer -- new-table )
    '[ _ _ substitute ] assoc-map
    [ nip ] assoc-filter ;

: assoc-answers ( table questions answer -- new-table )
    '[ _ assoc-answer ] each ;

DEFER: make-condition

: (make-condition) ( table questions question -- condition )
    [ 2nip ]
    [ swap [ t assoc-answer ] dip make-condition ]
    [ swap [ f assoc-answer ] dip make-condition ] 3tri
    2dup = [ 2nip ] [ <condition> ] if ;

: make-condition ( table questions -- condition )
    [ keys ] [ unclip (make-condition) ] if-empty ;

GENERIC: class>questions ( class -- questions )
: compound-questions ( class -- questions ) seq>> [ class>questions ] gather ;
M: or-class class>questions compound-questions ;
M: and-class class>questions compound-questions ;
M: not-class class>questions class>> class>questions ;
M: object class>questions 1array ;

: table>questions ( table -- questions )
    values [ class>questions ] gather >array t swap remove ;

: table>condition ( table -- condition )
    ! input table is state => class
    >alist dup table>questions make-condition ;

: condition-map ( condition quot: ( obj -- obj' ) -- new-condition ) 
    over condition? [
        [ [ question>> ] [ yes>> ] [ no>> ] tri ] dip
        '[ _ condition-map ] bi@ <condition>
    ] [ call ] if ; inline recursive

: condition-states ( condition -- states )
    dup condition? [
        [ yes>> ] [ no>> ] bi
        [ condition-states ] bi@ append prune
    ] [ 1array ] if ;

: condition-at ( condition assoc -- new-condition )
    '[ _ at ] condition-map ;

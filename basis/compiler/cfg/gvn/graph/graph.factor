! Copyright (C) 2008, 2010 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors kernel math namespaces assocs ;
IN: compiler.cfg.gvn.graph

SYMBOL: input-expr-counter

! assoc mapping vregs to value numbers
! this is the identity on canonical representatives
SYMBOL: vregs>vns

! assoc mapping expressions to value numbers
SYMBOL: exprs>vns

! assoc mapping value numbers to instructions
SYMBOL: vns>insns

! assoc mapping vregs to *global* value numbers
SYMBOL: vregs>gvns

SYMBOL: changed?

: vn>insn ( vn -- insn ) vns>insns get at ;

! : vreg>vn ( vreg -- vn ) vregs>vns get [ ] cache ;

: vreg>vn ( vreg -- vn ) vregs>gvns get at ;

! : set-vn ( vn vreg -- ) vregs>vns get set-at ;

: local-vn ( vn vreg -- lvn )
    vregs>vns get ?at
    [ nip ]
    [ dupd vregs>vns get set-at ] if ;

: set-vn ( vn vreg -- )
    [ local-vn ] keep
    vregs>gvns get maybe-set-at [ changed? on ] when ;

: vreg>insn ( vreg -- insn ) vreg>vn vn>insn ;

: init-gvn ( -- )
    H{ } clone vregs>gvns set ;

: init-value-graph ( -- )
    0 input-expr-counter set
    H{ } clone vregs>vns set
    H{ } clone exprs>vns set
    H{ } clone vns>insns set ;
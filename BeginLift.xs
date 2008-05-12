#define PERL_CORE
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>

/* lifted from op.c */

#define LINKLIST(o) ((o)->op_next ? (o)->op_next : linklist((OP*)o))

/* pointer to old PL_check entersub entry to be populated in init */

STATIC OP *(*dbl_old_ck_entersub)(pTHX_ OP *op);

/* replacement PL_check entersub entry */

STATIC OP *dbl_ck_entersub(pTHX_ OP *o) {
  dSP;
  OP *kid;
  OP *last;
  OP *curop;
  OP *saved_next;
  HV *stash;
  I32 type = o->op_type;
  SV *sv;
  SV** stack_save;
  HV* to_lift;
  SV** to_lift_pack_ref;
  HV* to_lift_pack_hash;
  SV** to_lift_flag_ref;

  o = dbl_old_ck_entersub(aTHX_ o); /* let the original do its job */

  kid = cUNOPo->op_first;

  if (kid->op_type != OP_NULL) /* pushmark for method call ... */
    return o;

  last = kLISTOP->op_last;

  if (last->op_type != OP_NULL) /* not what we expected */
    return o;

  kid = cUNOPx(last)->op_first;

  if (kid->op_type != OP_GV) /* not a GV so ignore */
    return o;

  stash = GvSTASH(kGVOP_gv);

  /* printf("Calling GV %s -> %s\n",
    HvNAME(stash), GvNAME(kGVOP_gv)); */

  to_lift = get_hv("Devel::BeginLift::lift", FALSE);

  if (!to_lift)
    return o;

  to_lift_pack_ref = hv_fetch(to_lift, HvNAME(stash), strlen(HvNAME(stash)),
                               FALSE);

  if (!to_lift_pack_ref || !SvROK(*to_lift_pack_ref))
    return o; /* not a hashref */

  to_lift_pack_hash = (HV*) SvRV(*to_lift_pack_ref);

  to_lift_flag_ref = hv_fetch(to_lift_pack_hash, GvNAME(kGVOP_gv),
                                strlen(GvNAME(kGVOP_gv)), FALSE);

  if (!to_lift_flag_ref || !SvTRUE(*to_lift_flag_ref))
    return o;

  /* shamelessly lifted from fold_constants in op.c */

  stack_save = SP;

  curop = LINKLIST(o);

  if (0) { /* call as macro */
    OP *arg;
    OP *gv;
    /* this means the argument pushing ops are not executed, only the GV to
     * resolve the call is, and B::OP objects will be made of all the opcodes
     * */
    PUSHMARK(SP); /* push a mark for the arguments */

    /* push an arg for every sibling op */
    for ( arg = curop->op_sibling; arg->op_sibling; arg = arg->op_sibling ) {
      XPUSHs(sv_bless(newRV_inc(newSViv(PTR2IV(arg))), gv_stashpv("B::LISTOP", 0)));
    }

    /* find the last non null before the lifted entersub */
    for ( kid = curop; kid->op_next != o; kid = kid->op_next ) {
      if ( kid->op_type == OP_GV )
          gv = kid;
    }

    PL_op = gv; /* make the call to our sub without evaluating the arg ops */
  } else {
    PL_op = curop;
  }

  /* stop right after the call */
  saved_next = o->op_next;
  o->op_next = NULL;

  PUTBACK;
  SAVETMPS;
  CALLRUNOPS(aTHX);
  SPAGAIN;

  if (SP > stack_save) { /* sub returned something */
    sv = POPs;
    if (o->op_targ && sv == PAD_SV(o->op_targ)) /* grab pad temp? */
      pad_swipe(o->op_targ,  FALSE);
    else if (SvTEMP(sv)) {      /* grab mortal temp? */
      (void)SvREFCNT_inc(sv);
      SvTEMP_off(sv);
    }

    if (SvROK(sv) && sv_derived_from(sv, "B::OP")) {
      OP *new = INT2PTR(OP *,SvIV((SV *)SvRV(sv)));
      new->op_sibling = NULL;

      /* FIXME this is bullshit */
      if ( (PL_opargs[new->op_type] & OA_CLASS_MASK) != OA_SVOP ) {
        new->op_next = saved_next;
      } else {
        new->op_next = new;
      }

      return new;
    }

    if (type == OP_RV2GV)
      return newGVOP(OP_GV, 0, (GV*)sv);

    return newSVOP(OP_CONST, 0, sv);
  } else {
    /* this bit not lifted, handles the 'sub doesn't return stuff' case
       which fold_constants can ignore */
    op_free(o);
    return newOP(OP_NULL, 0);
  }
}

static int initialized = 0;

MODULE = Devel::BeginLift  PACKAGE = Devel::BeginLift

PROTOTYPES: DISABLE

void
setup()
  CODE:
  if (!initialized++) {
    dbl_old_ck_entersub = PL_check[OP_ENTERSUB];
    PL_check[OP_ENTERSUB] = dbl_ck_entersub;
  }

void
teardown()
  CODE:
  /* ensure we only uninit when number of teardown calls matches 
     number of setup calls */
  if (initialized && !--initialized) {
    PL_check[OP_ENTERSUB] = dbl_old_ck_entersub;
  }

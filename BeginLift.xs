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
  OP *kid;
  OP *last;
  OP *curop;
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

  stack_save = PL_stack_sp;
  curop = LINKLIST(o);
  o->op_next = 0;
  PL_op = curop;
  CALLRUNOPS(aTHX);

  if (PL_stack_sp > stack_save) { /* sub returned something */
    sv = *(PL_stack_sp--);
    if (o->op_targ && sv == PAD_SV(o->op_targ)) /* grab pad temp? */
      pad_swipe(o->op_targ,  FALSE);
    else if (SvTEMP(sv)) {      /* grab mortal temp? */
      (void)SvREFCNT_inc(sv);
      SvTEMP_off(sv);
    }
    op_free(o);
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

//
//  File: %sys-ordered.h
//  Summary: "Order-dependent type macros"
//  Project: "Rebol 3 Interpreter and Run-time (Ren-C branch)"
//  Homepage: https://github.com/metaeducation/ren-c/
//
//=////////////////////////////////////////////////////////////////////////=//
//
// Copyright 2012 REBOL Technologies
// Copyright 2012-2018 Rebol Open Source Contributors
// REBOL is a trademark of REBOL Technologies
//
// See README.md and CREDITS.md for more information.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
//=////////////////////////////////////////////////////////////////////////=//
//
// These macros embed specific knowledge of the type ordering.  Basically any
// changes to %types.r mean having to take into account fixups here.
//
// !!! Review how these might be auto-generated from the table.
//
// !!! There was a historical linkage between the order of types and the
// TOKEN_XXX values.  That might be interesting to exploit for an optimization
// in the future...see notes on the tokens regarding this.
//


// Some of the tests are bitflag based.  This makes Rebol require a 64-bit
// integer, so tricks that would not require it for building would be good.
// (For instance, if all the types being tested fit in a 32-bit range.)
//
#define FLAGIT_KIND(t) \
    (cast(uint_fast64_t, 1) << (t)) // makes a 64-bit bitflag


//=//// QUOTED ////////////////////////////////////////////////////////////=//
//
// Testing for QUOTED! is special, as it isn't just the REB_QUOTED type, but
// also multiplexed as values > REB_64.  See %sys-quoted.h
//
// !!! Review making this test faster as just `k >= REB_QUOTED` by positioning
// the QUOTED! datatype past all the pseudotypes (e.g. at 63).  This would
// raise REB_MAX, and inflate all the tables for dispatch to 64 items, which
// is not really a big deal...but there are likely other consequences.

inline static bool IS_QUOTED_KIND(REBYTE k)
  { return k == REB_QUOTED or k >= REB_64; }

#define IS_QUOTED(v) \
    IS_QUOTED_KIND(KIND_BYTE(v))


//=//// BINDABILITY ///////////////////////////////////////////////////////=//
//
// Note that an "in-situ" QUOTED! (not a REB_QUOTED kind byte, but using
// larger REB_MAX values) is bindable if the cell it's overlaid into is
// bindable.  It has to handle binding exactly as its contained value.
//
// Actual REB_QUOTEDs (used for higher escape values) have to use a separate
// cell for storage.  The REB_QUOTED type is in the range of enum values that
// report bindability, even if it's storing a type that uses the ->extra field
// for something else.  This is mitigated by putting nullptr in the binding
// field of the REB_QUOTED portion of the cell, instead of mirroring the
// ->extra field of the contained cell...so it comes off as "specified" in
// those cases.
//
// Also note that the MIRROR_BYTE() is what is being tested--e.g. the type
// that the cell payload and extra actually are *for*.  This is what gives
// the CELL_KIND() as opposed to the VAL_TYPE

#define IS_BINDABLE_KIND(k) \
    ((k) >= REB_OBJECT)

#define Is_Bindable(v) \
    IS_BINDABLE_KIND(CELL_KIND_UNCHECKED(v))  // checked elsewhere


//=//// INERTNESS ////////////////////////////////////////////////////////=//
//
// All the inert types are grouped together to make this test fast.
//

inline static bool ANY_INERT_KIND(REBYTE k) {
    assert(k >= REB_BLANK);  // can't call on end/null/void
    return k <= REB_BLOCK;
}

#define ANY_INERT(v) \
    ANY_INERT_KIND(KIND_BYTE(v))

#define ANY_EVALUATIVE(v) \
    (not ANY_INERT_KIND(KIND_BYTE(v)))


//=//// FAST END+VOID+NULL TESTING ////////////////////////////////////////=//
//
// There are many cases where end/void/null all have special handling or need
// to raise errors.  Rather than saying:
//
//     if (IS_END(v)) { fail ("end"); }
//     if (IS_VOID(v)) { fail ("void"); }
//     if (IS_NULL(v)) { fail ("null"); }
//     CommonCaseStuff(v);
//
// This can be collapsed down to one test in the common case, with:
//
//     if (IS_NULLED_OR_VOID_OR_END(v)) {
//        if (IS_END(v)) { fail ("end"); }
//        if (IS_VOID(v)) { fail {"void"); }
//        fail ("null");
//     }
//     CommonCaseStuff(v);

inline static bool IS_NULLED_OR_VOID_KIND(REBYTE k) {
    assert(k != REB_0_END);
    return k <= REB_VOID;
}

#define IS_NULLED_OR_VOID(v) \
    IS_NULLED_OR_VOID_KIND(KIND_BYTE(v))

inline static bool IS_NULLED_OR_VOID_OR_END_KIND(REBYTE k)
    { return k <= REB_VOID; }

#define IS_NULLED_OR_VOID_OR_END(v) \
    IS_NULLED_OR_VOID_OR_END_KIND(KIND_BYTE_UNCHECKED(v))

inline static bool IS_NULLED_OR_BLANK_KIND(REBYTE k)
    { return k == REB_NULLED or k == REB_BLANK; }

#define IS_NULLED_OR_BLANK(v) \
    IS_NULLED_OR_BLANK_KIND(KIND_BYTE(v))


//=//// TYPE CATEGORIES ///////////////////////////////////////////////////=//

#define ANY_VALUE(v) \
    (KIND_BYTE(v) != REB_NULLED)

inline static bool ANY_SCALAR_KIND(REBYTE k)
    { return k >= REB_LOGIC and k <= REB_PAIR; }

#define ANY_SCALAR(v) \
    ANY_SCALAR_KIND(KIND_BYTE(v))

inline static bool ANY_STRING_KIND(REBYTE k)
    { return k >= REB_TEXT and k <= REB_ISSUE; }

#define ANY_STRING(v) \
    ANY_STRING_KIND(KIND_BYTE(v))

#define ANY_BINSTR_KIND_EVIL_MACRO \
    (k >= REB_BINARY and k <= REB_ISSUE)


inline static bool ANY_BINSTR_KIND(REBYTE k)
    { return ANY_BINSTR_KIND_EVIL_MACRO; }

#define ANY_BINSTR(v) \
    ANY_BINSTR_KIND(KIND_BYTE(v))


#define ANY_ARRAY_OR_PATH_KIND_EVIL_MACRO \
    (k < REB_64 and did (FLAGIT_KIND(k) & (TS_ARRAY | TS_PATH)))

inline static bool ANY_ARRAY_OR_PATH_KIND(REBYTE k)
    { return ANY_ARRAY_OR_PATH_KIND_EVIL_MACRO; }

#define ANY_ARRAY_OR_PATH(v) \
    ANY_ARRAY_OR_PATH_KIND(KIND_BYTE(v))


#define ANY_ARRAY_KIND_EVIL_MACRO \
    (k < REB_64 and did (FLAGIT_KIND(k) & TS_ARRAY))

inline static bool ANY_ARRAY_KIND(REBYTE k)
    { return ANY_ARRAY_KIND_EVIL_MACRO; }

#define ANY_ARRAY(v) \
    ANY_ARRAY_KIND(KIND_BYTE(v))


#define ANY_SERIES_KIND_EVIL_MACRO \
    (k < 64 and did (FLAGIT_KIND(k) & TS_SERIES))

inline static bool ANY_SERIES_KIND(REBYTE k)
    { return ANY_SERIES_KIND_EVIL_MACRO; }

#define ANY_SERIES(v) \
    ANY_SERIES_KIND(KIND_BYTE(v))


// !!! The ANY-WORD! classification is an odd one, because it's not just
// WORD!/GET-WORD!/SET-WORD! but includes ISSUE!.  Ren-C is looking at avenues
// of attack for this to let strings hold bindings.  To make the ANY_INERT()
// test fast, issue is grouped with the inert types...not the other words.

#define ANY_WORD_KIND_EVIL_MACRO \
    (k < 64 and did (FLAGIT_KIND(k) & TS_WORD))

inline static bool ANY_WORD_KIND(REBYTE k)
    { return ANY_WORD_KIND_EVIL_MACRO; }

#define ANY_WORD(v) \
    ANY_WORD_KIND(KIND_BYTE(v))

inline static bool ANY_PLAIN_GET_SET_WORD_KIND(REBYTE k)
    { return k == REB_WORD or k == REB_GET_WORD or k == REB_SET_WORD; }

#define ANY_PLAIN_GET_SET_WORD(v) \
    ANY_PLAIN_GET_SET_WORD_KIND(KIND_BYTE(v))


#define ANY_PATH_KIND_EVIL_MACRO \
    (k < 64 and did (FLAGIT_KIND(k) & TS_PATH))

inline static bool ANY_PATH_KIND(REBYTE k)
    { return ANY_PATH_KIND_EVIL_MACRO; }

#define ANY_PATH(v) \
    ANY_PATH_KIND(KIND_BYTE(v))


inline static bool ANY_BLOCK_KIND(REBYTE k)
    { return k == REB_BLOCK or k == REB_GET_BLOCK
        or k == REB_SET_BLOCK or k == REB_SYM_BLOCK; }

#define ANY_BLOCK(v) \
    ANY_BLOCK_KIND(KIND_BYTE(v))


inline static bool ANY_GROUP_KIND(REBYTE k)
    { return k == REB_GROUP or k == REB_GET_GROUP
        or k == REB_SET_GROUP or k == REB_SYM_GROUP; }

#define ANY_GROUP(v) \
    ANY_GROUP_KIND(KIND_BYTE(v))


inline static bool ANY_CONTEXT_KIND(REBYTE k)
    { return k >= REB_OBJECT and k <= REB_PORT; }

#define ANY_CONTEXT(v) \
    ANY_CONTEXT_KIND(KIND_BYTE(v))


inline static bool ANY_NUMBER_KIND(REBYTE k)
    { return k == REB_INTEGER or k == REB_DECIMAL or k == REB_PERCENT; }

#define ANY_NUMBER(v) \
    ANY_NUMBER_KIND(KIND_BYTE(v))


//=//// XXX <=> SET-XXX! <=> GET-XXX! TRANSFORMATION //////////////////////=//
//
// Note that grouping the blocks and paths and words together is more
// important than some property to identify all the GETs/SETs together.

inline static bool ANY_GET_KIND(REBYTE k) {
    return k >= REB_GET_BLOCK and k <= REB_GET_WORD;
}

inline static bool ANY_SET_KIND(REBYTE k) {
    return k >= REB_SET_BLOCK and k <= REB_SET_WORD;
}

inline static bool ANY_PLAIN_KIND(REBYTE k) {
    return k >= REB_BLOCK and k <= REB_WORD;
}

inline static bool ANY_SYM_KIND(REBYTE k) {
    return k >= REB_SYM_BLOCK and k <= REB_SYM_WORD;
}

inline static enum Reb_Kind UNGETIFY_ANY_GET_KIND(REBYTE k) {
    assert(ANY_GET_KIND(k));
    return cast(enum Reb_Kind, k - 8);
}

inline static enum Reb_Kind UNSETIFY_ANY_SET_KIND(REBYTE k) {
    assert(ANY_SET_KIND(k));
    return cast(enum Reb_Kind, k - 4);
}

inline static enum Reb_Kind UNSYMIFY_ANY_SYM_KIND(REBYTE k) {
    assert(ANY_SYM_KIND(k));
    return cast(enum Reb_Kind, k + 4);
}

inline static enum Reb_Kind SETIFY_ANY_PLAIN_KIND(REBYTE k) {
    assert(ANY_PLAIN_KIND(k));
    return cast(enum Reb_Kind, k + 4);
}

inline static enum Reb_Kind GETIFY_ANY_PLAIN_KIND(REBYTE k) {
    assert(ANY_PLAIN_KIND(k));
    return cast(enum Reb_Kind, k + 8);
}

inline static enum Reb_Kind SYMIFY_ANY_PLAIN_KIND(REBYTE k) {
    assert(ANY_PLAIN_KIND(k));
    return cast(enum Reb_Kind, k - 4);
}


//=//// "PARAM" CELLS /////////////////////////////////////////////////////=//
//
// !!! Due to the scarcity of bytes in cells, yet a desire to use them for
// parameters, they are a kind of "container" class in the KIND_BYTE() while
// the actual CELL_KIND (via MIRROR_BYTE()) is a REB_TYPESET.
//
// Making the typeset expression more sophisticated to clearly express a list
// of parameter flags is something planned for the near future.

inline static bool IS_PARAM_KIND(REBYTE k)
    { return k >= REB_P_NORMAL and k <= REB_P_RETURN; }

#define IS_PARAM(v) \
    IS_PARAM_KIND(KIND_BYTE(v))

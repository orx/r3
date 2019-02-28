//
//  File: %dev-dns.c
//  Summary: "Device: DNS access"
//  Project: "Rebol 3 Interpreter and Run-time (Ren-C branch)"
//  Homepage: https://github.com/metaeducation/ren-c/
//
//=////////////////////////////////////////////////////////////////////////=//
//
// Copyright 2012 REBOL Technologies
// Copyright 2012-2017 Rebol Open Source Contributors
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
// Calls local DNS services for domain name lookup.
//
// See MS WSAAsyncGetHost* details regarding multiple requests.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "reb-host.h"
#include "sys-net.h"
#include "reb-net.h"

extern DEVICE_CMD Init_Net(REBREQ *); // Share same init
extern DEVICE_CMD Quit_Net(REBREQ *);


//
//  Open_DNS: C
//
DEVICE_CMD Open_DNS(REBREQ *sock)
{
    Req(sock)->flags |= RRF_OPEN;
    return DR_DONE;
}


//
//  Close_DNS: C
//
// Note: valid even if not open.
//
DEVICE_CMD Close_DNS(REBREQ *sock)
{
    struct rebol_devreq *req = Req(sock);

    // Terminate a pending request:
    if (ReqNet(sock)->host_info)
        rebFree(ReqNet(sock)->host_info);
    ReqNet(sock)->host_info = nullptr;

    req->requestee.handle = 0;
    req->flags &= ~RRF_OPEN;
    return DR_DONE; // Removes it from device's pending list (if needed)
}


//
//  Read_DNS: C
//
// Initiate the GetHost request and return immediately.
// Note the temporary results buffer (must be freed later by the caller).
//
// !!! R3-Alpha used WSAAsyncGetHostByName and WSAAsyncGetHostByName to do
// non-blocking DNS lookup on Windows.  These functions are deprecated, since
// they do not have IPv6 equivalents...so applications that want asynchronous
// lookup are expected to use their own threads and call getnameinfo().
//
// !!! R3-Alpha was written to use the old non-reentrant form in POSIX, but
// glibc2 implements _r versions.
//
DEVICE_CMD Read_DNS(REBREQ *sock)
{
    struct rebol_devreq *req = Req(sock);
    char *host = rebAllocN(char, MAXGETHOSTSTRUCT);

    HOSTENT *he;
    if (req->modes & RST_REVERSE) {
        // 93.184.216.34 => example.com
        he = gethostbyaddr(
            cast(char*, &ReqNet(sock)->remote_ip), 4, AF_INET
        );
        if (he != NULL) {
            ReqNet(sock)->host_info = host; //???
            req->common.data = b_cast(he->h_name);
            req->flags |= RRF_DONE;
            return DR_DONE;
        }
    }
    else {
        // example.com => 93.184.216.34
        he = gethostbyname(s_cast(req->common.data));
        if (he != NULL) {
            ReqNet(sock)->host_info = host; // ?? who deallocs?
            memcpy(&ReqNet(sock)->remote_ip, *he->h_addr_list, 4); //he->h_length);
            req->flags |= RRF_DONE;
            return DR_DONE;
        }
    }

    rebFree(host);
    ReqNet(sock)->host_info = NULL;

    switch (h_errno) {
    case HOST_NOT_FOUND: // The specified host is unknown
    case NO_ADDRESS: // (or NO_DATA) name is valid but has no IP
        //
        // The READ should return a blank in these cases, vs. raise an
        // error, for convenience in handling.
        //
        break;

    case NO_RECOVERY:
        rebJumps(
            "FAIL {A nonrecoverable name server error occurred}",
            rebEND
        );

    case TRY_AGAIN:
        rebJumps(
            "FAIL {Temporary error on authoritative name server}",
            rebEND
        );

    default:
        rebJumps("FAIL {Unknown host error}", rebEND);
    }

    req->flags |= RRF_DONE;
    return DR_DONE;
}



/***********************************************************************
**
**  Command Dispatch Table (RDC_ enum order)
**
***********************************************************************/

static DEVICE_CMD_CFUNC Dev_Cmds[RDC_MAX] =
{
    Init_Net,   // Shared init - called only once
    Quit_Net,   // Shared
    Open_DNS,
    Close_DNS,
    Read_DNS,
    0  // write
};

DEFINE_DEV(Dev_DNS, "DNS", 1, Dev_Cmds, RDC_MAX, sizeof(struct devreq_net));

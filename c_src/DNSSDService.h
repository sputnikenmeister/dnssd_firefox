/* -*- Mode: C; tab-width: 4 -*-
 *
 * Copyright (c) 2009 Apple Computer, Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _DNSSDSERVICE_H
#define _DNSSDSERVICE_H

#include "IDNSSD.h"
#include "nsIThread.h"
#include "nsIRunnable.h"
#include "prtpool.h"
#include "nsStringAPI.h"
#include <dns_sd.h>
#include <string>

#define DNSSDSERVICE_CONTRACTID "@dnssd.me/DNSSDService;1"
#define DNSSDSERVICE_CLASSNAME "DNSSDService"
#define DNSSDSERVICE_CLASSNAMER DNSSDService
#define DNSSDSERVICE_CID { 0xe8e81354, 0x2bf5, 0x41bb, { 0xbc, 0x61, 0x6a, 0xed, 0x6c, 0x88, 0xe0, 0x17 } }

/* Header file */
class DNSSDSERVICE_CLASSNAMER : public IDNSSDService, nsIRunnable
{
public:
	NS_DECL_ISUPPORTS
	NS_DECL_IDNSSDSERVICE
	NS_DECL_NSIRUNNABLE
	DNSSDService();
	DNSSDService(nsISupports * callback);
	virtual ~DNSSDService();
private:
	static void DNSSD_API BrowseReply (DNSServiceRef sdRef,
									   DNSServiceFlags flags,
									   uint32_t interfaceIndex,
									   DNSServiceErrorType errorCode,
									   const char * serviceName,
									   const char * regtype,
									   const char * replyDomain,
									   void * context);
	static void DNSSD_API ResolveReply (DNSServiceRef sdRef,
										DNSServiceFlags flags,
										uint32_t interfaceIndex,
										DNSServiceErrorType errorCode,
										const char * fullname,
										const char * hosttarget,
										uint16_t port,
										uint16_t txtLen,
										const unsigned char * txtRecord,
										void * context);
	static void Read(void * arg);
	nsresult SetupNotifications();
	void Cleanup();
	PRThreadPool * m_threadPool;
	DNSServiceRef m_sdRef;
	nsISupports * m_callback;
	PRFileDesc * m_fileDesc;
	PRJobIoDesc m_iod;
	PRJob * m_job;
	PRBool m_stopped;
};

#endif

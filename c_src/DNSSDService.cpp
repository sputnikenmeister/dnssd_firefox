/* -*- Mode: C; tab-width: 4 -*-
 *
 * Copyright (c) 2009 Apple Computer, Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *	   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "DNSSDService.h"
#include "nsThreadUtils.h"
#include "nsIEventTarget.h"
#include "private/pprio.h"
#include <string>

NS_IMPL_ISUPPORTS2(DNSSDService, IDNSSDService, nsIRunnable)

DNSSDService::DNSSDService()
:
	m_threadPool(NULL),
	m_sdRef(NULL),
	m_callback(NULL),
	m_fileDesc(NULL),
	m_job(NULL),
	m_stopped(PR_FALSE)
{
}

DNSSDService::DNSSDService(nsISupports * callback)
:
	m_threadPool(NULL),
	m_sdRef(NULL),
	m_callback(callback),
	m_fileDesc(NULL),
	m_job(NULL),
	m_stopped(PR_FALSE)
{
}

DNSSDService::~DNSSDService() {
  Cleanup();
}

void DNSSDService::Cleanup() {
  m_stopped = PR_TRUE;
  if (m_job) {
	PR_CancelJob(m_job);
	m_job = NULL;
  }
  if (m_threadPool != NULL) {
	PR_ShutdownThreadPool(m_threadPool);
	m_threadPool = NULL;
  }
  if (m_fileDesc != NULL) {
	PR_Close(m_fileDesc);
	m_fileDesc = NULL;
  }
  if (m_sdRef) {
	DNSServiceRefDeallocate(m_sdRef);
	m_sdRef = NULL;
  }
}

nsresult DNSSDService::SetupNotifications() {
  if (m_stopped) return NS_OK;
  m_iod.socket = m_fileDesc;
  m_iod.timeout = PR_INTERVAL_NO_TIMEOUT;
  m_job = PR_QueueJob_Read( m_threadPool, &m_iod, Read, this, PR_FALSE );
  return (m_job) ? NS_OK : NS_ERROR_FAILURE;
}

NS_IMETHODIMP DNSSDService::Browse(IDNSSDServiceBrowseCallback *callback,
								   IDNSSDService **_retval NS_OUTPARAM) {
  DNSSDService * service = NULL;
  DNSServiceErrorType dnsErr = 0;
  nsresult err = 0;
  *_retval = NULL;
  try {
	service = new DNSSDService(callback);
  }
  catch ( ... ) {
	service = NULL;
  }
  if ( service == NULL ) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  dnsErr = DNSServiceBrowse(&service->m_sdRef, 0, 0, "_http._tcp", "",
							(DNSServiceBrowseReply) BrowseReply, service);
  if (dnsErr != kDNSServiceErr_NoError) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  if ((service->m_fileDesc = PR_ImportTCPSocket(DNSServiceRefSockFD(service->m_sdRef))) == NULL ) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  if ((service->m_threadPool = PR_CreateThreadPool(1, 1, 8192)) == NULL) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  err = service->SetupNotifications();
  if (err != NS_OK) {
	goto exit;
  }
  callback->AddRef();
  service->AddRef();
  *_retval = service;
  err = NS_OK;
 exit:
  if (err && service) {
	delete service;
	service = NULL;
  }
  return err;
}

NS_IMETHODIMP DNSSDService::Resolve(const nsAString & name,
									const nsAString & regtype,
									const nsAString & domain,
									IDNSSDServiceResolveCallback *callback,
									IDNSSDService **_retval NS_OUTPARAM) {
  DNSSDService	*	service	= NULL;
  DNSServiceErrorType dnsErr	= 0;
  nsresult			err		= 0;
  *_retval = NULL;
  try {
	service = new DNSSDService(callback);
  }
  catch (...) {
	service = NULL;
  }
  if (service == NULL) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  dnsErr = DNSServiceResolve(&service->m_sdRef, 0, 0,
							 NS_ConvertUTF16toUTF8(name).get(),
							 NS_ConvertUTF16toUTF8( regtype ).get(),
							 NS_ConvertUTF16toUTF8( domain ).get(),
							 (DNSServiceResolveReply) ResolveReply, service);
  if (dnsErr != kDNSServiceErr_NoError) {
	err = NS_ERROR_FAILURE;
	goto exit;
  }
  if ((service->m_fileDesc = PR_ImportTCPSocket(DNSServiceRefSockFD(service->m_sdRef))) == NULL)
	{
		err = NS_ERROR_FAILURE;
		goto exit;
	}
	if ((service->m_threadPool = PR_CreateThreadPool(1, 1, 8192)) == NULL)
	{
		err = NS_ERROR_FAILURE;
		goto exit;
	}
	err = service->SetupNotifications();
	if (err != NS_OK)
	{
	    goto exit;
	}
	callback->AddRef();
	service->AddRef();
	*_retval = service;
	err = NS_OK;
exit:
	if (err && service) {
	  delete service;
	  service = NULL;
	}
	return err;
}

NS_IMETHODIMP DNSSDService::Stop() {
  m_stopped = PR_TRUE;
  if (m_job != NULL) {
	PR_CancelJob( m_job );
	m_job = NULL;
  }
  if (m_fileDesc != NULL) {
	PR_Close(m_fileDesc);
	m_fileDesc = NULL;
  }
  if (m_sdRef) {
	DNSServiceRefDeallocate(m_sdRef);
	m_sdRef = NULL;
  }
  return NS_OK;
}

void DNSSDService::Read(void * arg) {
  NS_PRECONDITION(arg != NULL, "arg is NULL");
  NS_DispatchToMainThread((DNSSDService*) arg);
}

NS_IMETHODIMP DNSSDService::Run() {
  nsresult err;
  NS_PRECONDITION(m_sdRef != NULL, "m_sdRef is NULL");
  m_job = NULL;
  err = NS_OK;
  if (PR_Available(m_fileDesc) > 0 && m_sdRef != NULL) {
	if (DNSServiceProcessResult(m_sdRef) == kDNSServiceErr_NoError) {
	  err = SetupNotifications();
	} else {
	  err = NS_ERROR_FAILURE;
	}
  }
  return err;
}

void DNSSD_API DNSSDService::BrowseReply(DNSServiceRef sdRef,
										 DNSServiceFlags flags,
										 uint32_t interfaceIndex,
										 DNSServiceErrorType errorCode,
										 const char * serviceName,
										 const char * regtype,
										 const char * replyDomain,
										 void * context) {
  DNSSDService * self = (DNSSDService*) context;
  // This should never be NULL, but let's be defensive.
  if (self != NULL) {
	IDNSSDServiceBrowseCallback * callback = (IDNSSDServiceBrowseCallback*) self->m_callback;
	// Same for this
	if (callback != NULL) {
	  callback->Callback(self,
						 (flags & kDNSServiceFlagsAdd) ? PR_TRUE : PR_FALSE,
						 interfaceIndex, errorCode,
						 NS_ConvertUTF8toUTF16(serviceName),
						 NS_ConvertUTF8toUTF16(regtype),
						 NS_ConvertUTF8toUTF16(replyDomain));
	}
  }
}

void DNSSD_API DNSSDService::ResolveReply(DNSServiceRef sdRef,
										  DNSServiceFlags flags,
										  uint32_t interfaceIndex,
										  DNSServiceErrorType errorCode,
										  const char * fullname,
										  const char * hosttarget,
										  uint16_t port,
										  uint16_t txtLen,
										  const unsigned char * txtRecord,
										  void * context) {
  DNSSDService * self = ( DNSSDService* ) context;
  // This should never be NULL, but let's be defensive.
  if (self != NULL) {
	IDNSSDServiceResolveCallback * callback = (IDNSSDServiceResolveCallback*) self->m_callback;
	// Same for this
	if (callback != NULL) {
	  std::string path = "";
	  const void * value = NULL;
	  uint8_t valueLen = 0;
	  value = TXTRecordGetValuePtr(txtLen, txtRecord, "path", &valueLen);
	  if (value && valueLen) {
		char * temp;
		temp = new char[ valueLen + 1 ];
		if (temp) {
		  memset( temp, 0, valueLen + 1 );
		  memcpy( temp, value, valueLen );
		  path = temp;
		  delete [] temp;
		}
	  }
	  callback->Callback(self, interfaceIndex, errorCode,
						 NS_ConvertUTF8toUTF16(fullname),
						 NS_ConvertUTF8toUTF16(hosttarget),
						 ntohs(port), NS_ConvertUTF8toUTF16(path.c_str()));
	}
  }
}

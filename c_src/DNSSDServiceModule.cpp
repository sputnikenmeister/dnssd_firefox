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

#include "mozilla/ModuleUtils.h"
#include "nsIClassInfoImpl.h"
#include "DNSSDService.h"

NS_GENERIC_FACTORY_CONSTRUCTOR(DNSSDService)

NS_DEFINE_NAMED_CID(DNSSDSERVICE_CID);

static const mozilla::Module::CIDEntry kDNSSDServiceCIDs[] = {
  { &kDNSSDSERVICE_CID, false, NULL, DNSSDServiceConstructor },
  { NULL }
};

static const mozilla::Module::ContractIDEntry kDNSSDServiceContracts[] = {
  { DNSSDSERVICE_CONTRACTID, &kDNSSDSERVICE_CID },
  { NULL }
};

static const mozilla::Module::CategoryEntry kDNSSDServiceCategories[] = {
  { NULL }
};


static const mozilla::Module kDNSSDServiceModule = {
  mozilla::Module::kVersion,
  kDNSSDServiceCIDs,
  kDNSSDServiceContracts,
  kDNSSDServiceCategories
};

NSMODULE_DEFN(DNSSDServiceModule) = &kDNSSDServiceModule;

NS_IMPL_MOZILLA192_NSGETMODULE(&kDNSSDServiceModule)

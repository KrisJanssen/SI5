#pragma once

#include <windows.h>
#include <map>
#include "stdafx.h"

//#define CONSOLEDEBUG
#undef CONSOLEDEBUG

#ifdef CONSOLEDEBUG
// Might be able to simplify this, the only reason this isn't a function is wrapping cprintf.
#define CONSOLEPRINT(...)					   \
  do {                                                             \
    NIFPGAMexDebugger::getInstance()->preConsolePrint();		   \
    _cprintf(__VA_ARGS__);					   \
    NIFPGAMexDebugger::getInstance()->postConsolePrint();	   \
  } while (0)
#define CONSOLETRACE(...) CONSOLEPRINT("NIFpgaMEX. %s: line %d\n",__FUNCTION__,__LINE__)
#define CFAEASSERT(tf,...)			\
  if (!(tf)) {					\
    CONSOLEPRINT(__VA_ARGS__);			\
  }
#else
#define CONSOLETRACE(...)
#define CONSOLEPRINT(...)
#define CFAEASSERT(tf,...) { assert(tf); }
#endif

/*
  NIFPGAMexDebugger
  
  Singleton class for debugging.

 */
class NIFPGAMexDebugger
{
 public:
  
  static NIFPGAMexDebugger *getInstance(void);

  // Sets console text attributes for the calling thread.
  void setConsoleAttribsForThread(WORD wAttribs);

  // See CONSOLEPRINT() Macro, these are public only b/c I don't want
  // to figure out how to wrap _cprintf.
  void preConsolePrint(void);
  void postConsolePrint(void);  

 private:

  NIFPGAMexDebugger(void);

  ~NIFPGAMexDebugger(void);

  WORD getConsoleAttribsForThread(DWORD threadID);

 private:
   std::map<DWORD,WORD> fThreadID2ConsoleAttribs;
   CRITICAL_SECTION fConsoleWriteCS;
   HANDLE fConsoleScreenBuffer;
};

namespace CFAEMisc 
{
  void requestLockMutex(HANDLE h);
  void releaseLockMutex(HANDLE h);

  // Get a scalar-integer-valued property off a scalar object.
  int getIntScalarPropFromMX(const mxArray *obj, const char *propname);

  // Assertion using mexErrMsgTxt.
  void mexAssert(bool cond,const char *msg);

  void closeHandleAndSetToNULL(HANDLE &h);
}
  

//--------------------------------------------------------------------------//
// Misc.h                                                                   //
// Copyright © 2015 Vidrio Technologies, LLC                                //
//                                                                          //
// ScanImage 5 is licensed under the Apache License, Version 2.0            //
// (the "License"); you may not use any files contained within the          //
// ScanImage 5 release  except in compliance with the License.              //
// You may obtain a copy of the License at                                  //
// http://www.apache.org/licenses/LICENSE-2.0                               //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
//--------------------------------------------------------------------------//

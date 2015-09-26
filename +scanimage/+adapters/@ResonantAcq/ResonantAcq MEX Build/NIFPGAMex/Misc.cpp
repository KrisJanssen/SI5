#include "stdafx.h"
#include <windows.h>
#include "mex.h"
#include "Misc.h"

NIFPGAMexDebugger * NIFPGAMexDebugger::getInstance(void)
{
  static NIFPGAMexDebugger *tmd = NULL;
  if (tmd==NULL) {
    tmd = new NIFPGAMexDebugger();
    assert(tmd!=NULL);
  }
  return tmd;
}

void
NIFPGAMexDebugger::setConsoleAttribsForThread(WORD wAttribs)
{
  DWORD threadID = GetCurrentThreadId();
  fThreadID2ConsoleAttribs[threadID] = wAttribs;
}

void
NIFPGAMexDebugger::preConsolePrint(void)
{
  DWORD threadID = GetCurrentThreadId();
  WORD attribs = getConsoleAttribsForThread(threadID);
  EnterCriticalSection(&fConsoleWriteCS);
  SetConsoleTextAttribute(fConsoleScreenBuffer,attribs); 
}

void
NIFPGAMexDebugger::postConsolePrint(void)
{
  LeaveCriticalSection(&fConsoleWriteCS);
}

NIFPGAMexDebugger::NIFPGAMexDebugger(void) 
{
  BOOL ret = AllocConsole();
  assert(ret);
  fConsoleScreenBuffer = GetStdHandle(STD_OUTPUT_HANDLE);
  InitializeCriticalSection(&fConsoleWriteCS);
}

NIFPGAMexDebugger::~NIFPGAMexDebugger(void)
{
  DeleteCriticalSection(&fConsoleWriteCS);
  CloseHandle(fConsoleScreenBuffer);
}

WORD 
NIFPGAMexDebugger::getConsoleAttribsForThread(DWORD threadID)
{
  std::map<DWORD,WORD>::iterator it = 
    fThreadID2ConsoleAttribs.find(threadID);
  if (it!=fThreadID2ConsoleAttribs.end()) {
    return it->second;
  } else {
    return FOREGROUND_RED|FOREGROUND_INTENSITY; // default attribs
  } 
}


void
CFAEMisc::requestLockMutex(HANDLE h) 
{
  WaitForSingleObject(h, INFINITE);
}

void 
CFAEMisc::releaseLockMutex(HANDLE h) 
{
  ReleaseMutex(h);
}

int 
CFAEMisc::getIntScalarPropFromMX(const mxArray *a,const char *pname)
{
  assert(a!=NULL);
  mxArray *tmp = mxGetProperty(a,0,pname);
  assert(tmp!=NULL);
  int retval = (int)mxGetScalar(tmp);
  mxDestroyArray(tmp);
  return retval;
}

void 
CFAEMisc::mexAssert(bool cond,const char *msg)
{
  if (!cond) {
    mexErrMsgTxt(msg);
  }
}

void
CFAEMisc::closeHandleAndSetToNULL(HANDLE& h)
{
  if (h!=NULL) {
    CloseHandle(h);
    h = NULL;
  }
}

 


//--------------------------------------------------------------------------//
// Misc.cpp                                                                 //
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

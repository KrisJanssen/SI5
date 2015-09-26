// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

#include "targetver.h"

#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <conio.h>

// TODO: reference additional headers your program requires here
#include "mex.h"
#include "NiFpga.h"

#include "StateModelObject.h"
#include "Misc.h"
#include "AsyncMex.h" 
#include "FrameQueue.h"
#include "FrameCopier.h"
#include "TifWriter.h"
#include "MatlabParams.h"

//#include "LSM_SDK.h"
#include <wchar.h>
#include <share.h>  // for fsopen constants _SHARE_XXX
#include <assert.h> // used for ASSERT
#include <vector>
#include <string>
#include <matrix.h> // only for fwd declare mxArray *


//--------------------------------------------------------------------------//
// stdafx.h                                                                 //
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

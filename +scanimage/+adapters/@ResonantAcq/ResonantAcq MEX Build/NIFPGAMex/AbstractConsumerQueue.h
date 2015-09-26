#pragma once

#include <cstddef>

class AbstractConsumerQueue {

 public:
  
  virtual std::size_t recordSize(void) const = 0;

  virtual bool isEmpty(void) const = 0;

  // Returns the number of records currently in the queue.
  virtual unsigned long size(void) const = 0;

  // Return front of queue (thread unsafe)
  virtual const void* front_unsafe(void) const = 0;

  // Return front of queue, and lock queue until
  // front_checkin. Remember to call front_checkin when you are done!
  virtual const void* front_checkout(void) = 0;

  virtual void front_checkin(void) = 0;

  // Pop first record.
  virtual void pop_front(void) = 0;

};


//--------------------------------------------------------------------------//
// AbstractConsumerQueue.h                                                  //
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

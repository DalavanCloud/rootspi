#---Common Setting----------------------------------------------------------
include(${CTEST_SCRIPT_DIRECTORY}/rootCommon.cmake)

#---Enable roottest---------------------------------------------------------
if(CTEST_VERSION STREQUAL "master" OR CTEST_VERSION MATCHES "^v6-")
  set(testing_options "-Droottest=ON")
endif()

#---Set TCMalloc for fast builds--------------------------------------------
if(CTEST_BUILD_CONFIGURATION STREQUAL "Optimized")
  set(testing_options ${testing_options}" -Dtcmalloc=ON")
endif()

#---Compose the confguration options---------------------------------------- 
set(options -Dall=ON
            -Dtesting=ON
            ${testing_options}
            -DCMAKE_INSTALL_PREFIX=${CTEST_INSTALL_DIRECTORY}
            $ENV{ExtraCMakeOptions})
 
#---Special build options---------------------------------------------------
if("$ENV{BUILDOPTS}" STREQUAL "cxx14root7")
  set(options ${options} -Dcxx14=ON -Droot7=ON)
endif()

if("$ENV{CXX_VERSION}" STREQUAL "14")
  set(options ${options} -Dcxx14=ON)
elseif("$ENV{CXX_VERSION}" STREQUAL "17")
  set(options ${options} -Dcxx17=ON)
endif()

if("$ENV{BUILDOPTS}" STREQUAL "cxxmodules" OR
   "$ENV{BUILDOPTS}" STREQUAL "coverity")
  unset(CTEST_CHECKOUT_COMMAND)
endif()

if(CTEST_MODE STREQUAL continuous OR CTEST_MODE STREQUAL pullrequests)
  find_program(NINJA_EXECUTABLE ninja)
  if(NINJA_EXECUTABLE)
    set(CTEST_CMAKE_GENERATOR "Ninja")
  endif()
endif()

if ((CMAKE_GENERATOR MATCHES "Visual Studio") AND (CMAKE_GENERATOR_TOOLSET STREQUAL ""))
  set(options ${options} -Thost=x64)
endif()

separate_arguments(options)

#----Continuous-----------------------------------------------------------
if(CTEST_MODE STREQUAL continuous)
  set(empty $ENV{EMPTY_BINARY})
  if(empty)
    #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
    file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})
  else()
    file(GLOB testruns ${CTEST_BINARY_DIRECTORY}/Testing/*-*)
    if(testruns)
      file(REMOVE_RECURSE ${testruns})
    endif()
  endif()
  ctest_start (Continuous TRACK Continuous-${CTEST_VERSION})
  ctest_update(RETURN_VALUE updates)
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}
                  OPTIONS "${options}")
  ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
  ctest_build(BUILD ${CTEST_BINARY_DIRECTORY})
  ctest_submit(PARTS Update Configure Build)

#---Install---------------------------------------------------------------
elseif(CTEST_MODE STREQUAL install)

  #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})
  ctest_start(${CTEST_MODE} TRACK Install)
  ctest_update()
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}
                  OPTIONS "${options}"
                  APPEND)
  ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
  ctest_build(BUILD ${CTEST_BINARY_DIRECTORY} TARGET install APPEND)
  ctest_submit(PARTS Update Configure Build)
  #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})

#---Package---------------------------------------------------------------
elseif(CTEST_MODE STREQUAL package)

  #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})
  ctest_start(${CTEST_MODE} TRACK Package)
  ctest_update()
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}
                  OPTIONS "${options}"
                  APPEND)
  ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
  ctest_build(BUILD ${CTEST_BINARY_DIRECTORY} TARGET package APPEND)
  ctest_submit(PARTS Update Configure Build)

#----Pullrequests-----------------------------------------------------------
elseif(CTEST_MODE STREQUAL pullrequests)

  #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})

  unset(CTEST_CHECKOUT_COMMAND)
  set(CTEST_GIT_UPDATE_CUSTOM ${CTEST_GIT_COMMAND} -c user.name=sftnight
    -c user.email=sftnight@cern.ch rebase -f -v origin/$ENV{ghprbTargetBranch} origin/pr/$ENV{ghprbPullId}/head)

  ctest_start (Pullrequests TRACK Pullrequests)
  ctest_update(RETURN_VALUE updates)
  if(updates LESS 0) # stop if update error
    execute_process(COMMAND ${CTEST_GIT_COMMAND} rebase --abort WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY})
    ctest_submit(PARTS Update)
    message(FATAL_ERROR "Failed to rebase source branch on top of $ENV{ghprbTargetBranch}!")
  endif()
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}
                  OPTIONS "${options}")
  ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
  ctest_build(BUILD ${CTEST_BINARY_DIRECTORY})
  ctest_submit(PARTS Update Configure Build)

#---Experimental/Nightly----------------------------------------------------
else()

  #ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  file(REMOVE_RECURSE ${CTEST_BINARY_DIRECTORY})
  ctest_start(${CTEST_MODE})
  ctest_update(SOURCE ${CTEST_SOURCE_DIRECTORY})
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}
                  OPTIONS "${options}")
  ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
  ctest_build(BUILD ${CTEST_BINARY_DIRECTORY})
  ctest_submit(PARTS Update Configure Build)
endif()



# Staged by Zlyme: Buildroot host CMake has no HTTPS, so do not file(DOWNLOAD).
set(_GCEM_CANDIDATES
	"${CMAKE_CURRENT_LIST_DIR}/../gcem/include"
	"${CMAKE_SOURCE_DIR}/gcem/include")
foreach(_d IN LISTS _GCEM_CANDIDATES)
	if(EXISTS "${_d}/gcem.hpp")
		set(GCEM_INCLUDE_DIR "${_d}")
		break()
	endif()
endforeach()
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(GCEM REQUIRED_VARS GCEM_INCLUDE_DIR)
mark_as_advanced(GCEM_INCLUDE_DIR)

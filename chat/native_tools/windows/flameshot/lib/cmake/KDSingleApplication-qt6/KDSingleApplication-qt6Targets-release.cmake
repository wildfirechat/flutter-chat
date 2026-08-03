#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "KDAB::kdsingleapplication" for configuration "Release"
set_property(TARGET KDAB::kdsingleapplication APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(KDAB::kdsingleapplication PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/kdsingleapplication-qt6.lib"
  )

list(APPEND _cmake_import_check_targets KDAB::kdsingleapplication )
list(APPEND _cmake_import_check_files_for_KDAB::kdsingleapplication "${_IMPORT_PREFIX}/lib/kdsingleapplication-qt6.lib" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)

#!/bin/bash

function check_qgis() {
  env_var_exists QGIS_VERSION
  env_var_exists QGIS_INSTALL_DIR
  env_var_exists VERSION_grass_major
}

function bundle_qgis() {
  QGIS_CONTENTS_DIR=$QGIS_INSTALL_DIR/QGIS.app/Contents/
  QGIS_RECIPE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

  mkdir -p $BUNDLE_LIB_DIR/qgis

  try cp -av $QGIS_CONTENTS_DIR/Info.plist $BUNDLE_CONTENTS_DIR
  try cp -av $QGIS_CONTENTS_DIR/PkgInfo $BUNDLE_CONTENTS_DIR
  try cp -av $QGIS_CONTENTS_DIR/MacOS/QGIS $BUNDLE_MACOS_DIR
  try cp -av $QGIS_RECIPE_DIR/pyqgis-startup.py $BUNDLE_RESOURCES_DIR/python/

  # SERVER
  try cp -av $QGIS_CONTENTS_DIR/MacOS/fcgi-bin $BUNDLE_MACOS_DIR/fcgi-bin
  try mv  $BUNDLE_MACOS_DIR/fcgi-bin/qgis_mapserv.fcgi $BUNDLE_MACOS_DIR/fcgi-bin/_qgis_mapserv.fcgi
  try cp -av $QGIS_RECIPE_DIR/qgis_mapserv.fcgi $BUNDLE_MACOS_DIR/fcgi-bin/
  try cp -av $QGIS_CONTENTS_DIR/MacOS/bin/qgis_mapserver $BUNDLE_BIN_DIR/_qgis_mapserver
  try cp -av $QGIS_RECIPE_DIR/qgis_mapserver $BUNDLE_BIN_DIR/qgis_mapserver
  try cp -av $QGIS_CONTENTS_DIR/MacOS/lib/qgis/server $BUNDLE_LIB_DIR/qgis/

  # LIBS
  try cp -av $QGIS_CONTENTS_DIR/MacOS/lib/libqgis_app.* $BUNDLE_LIB_DIR
  try cp -av $QGIS_CONTENTS_DIR/MacOS/lib/libqgispython.* $BUNDLE_LIB_DIR
  try cp -av $QGIS_CONTENTS_DIR/MacOS/lib/libqgis_server.* $BUNDLE_LIB_DIR

  #### RESOURCES
  try rsync -av $QGIS_CONTENTS_DIR/Resources/ $BUNDLE_RESOURCES_DIR/ --exclude __pycache__
  try cp -av $QGIS_RECIPE_DIR/find_mod_spatialite.py $BUNDLE_RESOURCES_DIR/python/qgis/

  #### GRASS
  # Console module, in the GRASS Tools panel: src/plugins/grass/qtermwidget/tools.cpp
  #   - in get_kb_layout_dir() should be Resources/kb-layouts/
  mk_sym_link $BUNDLE_RESOURCES_DIR ./grass/qtermwidget/kb-layouts kb-layouts
  #   - get_color_schemes_dir() should be Resources/color-schemes/
  mk_sym_link $BUNDLE_RESOURCES_DIR ./grass/qtermwidget/color-schemes color-schemes
  # extra modules
  try cp -av $QGIS_CONTENTS_DIR/MacOS/lib/qgis/grass $BUNDLE_LIB_DIR/qgis/

  #### FRAMEWORKS
  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgis_analysis.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Header
  try rm -f $BUNDLE_FRAMEWORKS_DIR/qgis_analysis.framework/Headers

  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgis_core.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Headers
  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgis_gui.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Headers
  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgis_native.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Headers
  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgis_3d.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Headers
  try rsync -av $QGIS_CONTENTS_DIR/Frameworks/qgisgrass${VERSION_grass_major}.framework $BUNDLE_FRAMEWORKS_DIR/ --exclude Headers

  #### QGIS PROCESS
  try cp -av $QGIS_CONTENTS_DIR/MacOS/bin/qgis_process.app $BUNDLE_MACOS_DIR
  try cp -av $QGIS_RECIPE_DIR/qgis_process $BUNDLE_MACOS_DIR/bin/qgis_process

  #### PLUGINS
  try rsync -av $QGIS_CONTENTS_DIR/PlugIns/ $BUNDLE_PLUGINS_DIR/

  mkdir -p $BUNDLE_PLUGINS_DIR/designer
  try cp -av $QGIS_INSTALL_DIR/plugins/designer/libqgis_customwidgets.* $BUNDLE_PLUGINS_DIR/designer

  if [[ "$WITH_ORACLE" == "true" ]]; then
    mkdir -p $BUNDLE_PLUGINS_DIR/sqldrivers
    try cp -av $QGIS_INSTALL_DIR/plugins/sqldrivers/libqsqlocispatial.dylib $BUNDLE_PLUGINS_DIR/sqldrivers/
    ORACLE_CLIENT="$QGIS_RECIPE_DIR/../../../../external/oracle/instantclient"
    if [ ! -d "$ORACLE_CLIENT" ]; then
      error "invalid oracle basic-light client $ORACLE_CLIENT"
    fi
    try cp -av $ORACLE_CLIENT/libclntsh.* $BUNDLE_LIB_DIR/
    try cp -av $ORACLE_CLIENT/libnnz18.* $BUNDLE_LIB_DIR/
    try cp -av $ORACLE_CLIENT/libons.* $BUNDLE_LIB_DIR/
    try cp -av $ORACLE_CLIENT/libclntshcore.dylib.* $BUNDLE_LIB_DIR/
  fi
}

function fix_binaries_qgis() {
 chmod +x $BUNDLE_CONTENTS_DIR/MacOS/QGIS

 # RPATHS
 install_name_delete_rpath $DEPS_LIB_DIR $BUNDLE_CONTENTS_DIR/MacOS/QGIS
 install_name_delete_rpath $QT_BASE/clang_64/lib $BUNDLE_CONTENTS_DIR/MacOS/QGIS
 install_name_delete_rpath $QGIS_INSTALL_DIR/QGIS.app/Contents/MacOS/lib $BUNDLE_CONTENTS_DIR/MacOS/QGIS

 install_name_add_rpath @executable_path/../Frameworks $BUNDLE_CONTENTS_DIR/MacOS/QGIS
 install_name_add_rpath @executable_path/lib $BUNDLE_CONTENTS_DIR/MacOS/QGIS
 install_name_add_rpath @executable_path/../Resources/grass${VERSION_grass_major}${VERSION_grass_minor}/lib $BUNDLE_CONTENTS_DIR/MacOS/QGIS

 install_name_add_rpath @executable_path/../../Frameworks $BUNDLE_CONTENTS_DIR/MacOS/fcgi-bin/_qgis_mapserv.fcgi
 install_name_add_rpath @executable_path/../lib $BUNDLE_CONTENTS_DIR/MacOS/fcgi-bin/_qgis_mapserv.fcgi
 install_name_add_rpath @executable_path/../../Resources/grass${VERSION_grass_major}${VERSION_grass_minor}/lib $BUNDLE_CONTENTS_DIR/MacOS/fcgi-bin/_qgis_mapserv.fcgi

 install_name_add_rpath @executable_path/../../Frameworks $BUNDLE_CONTENTS_DIR/MacOS/bin/_qgis_mapserver
 install_name_add_rpath @executable_path/../lib $BUNDLE_CONTENTS_DIR/MacOS/bin/_qgis_mapserver
 install_name_add_rpath @executable_path/../../Resources/grass${VERSION_grass_major}${VERSION_grass_minor}/lib $BUNDLE_CONTENTS_DIR/MacOS/bin/_qgis_mapserver

 install_name_add_rpath @executable_path/../../../../Frameworks $BUNDLE_CONTENTS_DIR/MacOS/qgis_process.app/Contents/MacOS/qgis_process
 install_name_add_rpath @executable_path/../../../lib $BUNDLE_CONTENTS_DIR/MacOS/qgis_process.app/Contents/MacOS/qgis_process
 install_name_add_rpath @executable_path/../../../../Resources/grass${VERSION_grass_major}${VERSION_grass_minor}/lib $BUNDLE_CONTENTS_DIR/MacOS/qgis_process.app/Contents/MacOS/qgis_process

 install_name_add_rpath @loader_path/../../MacOS/lib $BUNDLE_CONTENTS_DIR/PlugIns/designer/libqgis_customwidgets.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib

 install_name_id @rpath/libqgispython.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/MacOS/lib/libqgispython.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib
 install_name_id @rpath/libqgis_server.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/MacOS/lib/libqgis_server.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib
 install_name_id @rpath/libqgis_app.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/MacOS/lib/libqgis_app.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib
 install_name_id @rpath/libqgis_customwidgets.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/PlugIns/designer/libqgis_customwidgets.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib

 install_name_add_rpath @executable_path/../../../../../Frameworks $BUNDLE_CONTENTS_DIR/MacOS/lib/qgis/grass/bin/qgis.g.browser7
 install_name_add_rpath @executable_path/../../../../lib $BUNDLE_CONTENTS_DIR/MacOS/lib/qgis/grass/bin/qgis.g.browser7
 install_name_add_rpath @executable_path/../../../../../Resources/grass${VERSION_grass_major}${VERSION_grass_minor}/lib $BUNDLE_CONTENTS_DIR/MacOS/lib/qgis/grass/bin/qgis.g.browser7

 if [[ "$WITH_HANA" == "true" ]]; then
  HANA_PROVIDER=PlugIns/qgis/libhanaprovider.so
 fi

 if [[ "$WITH_ORACLE" == "true" ]]; then
  ORACLE_PROVIDER=PlugIns/qgis/liboracleprovider.so
 fi

 # LIBS
 if [[ "$WITH_PDAL" == "true" ]]; then
      PDALPROVIDER=PlugIns/qgis/libpdalprovider.so
 fi

 for i in \
    MacOS/QGIS \
    MacOS/bin/_qgis_mapserver \
    MacOS/fcgi-bin/_qgis_mapserv.fcgi \
    MacOS/lib/qgis/server/libdummy.so \
    MacOS/lib/qgis/server/liblandingpage.so \
    MacOS/lib/qgis/server/libwcs.so \
    MacOS/lib/qgis/server/libwfs.so \
    MacOS/lib/qgis/server/libwfs3.so \
    MacOS/lib/qgis/server/libwms.so \
    MacOS/lib/qgis/server/libwmts.so  \
    MacOS/qgis_process.app/Contents/MacOS/qgis_process \
    Frameworks/qgis_core.framework/Versions/$QGIS_VERSION/qgis_core \
    Frameworks/qgis_3d.framework/Versions/$QGIS_VERSION/qgis_3d \
    Frameworks/qgis_analysis.framework/Versions/$QGIS_VERSION/qgis_analysis \
    Frameworks/qgis_gui.framework/Versions/$QGIS_VERSION/qgis_gui \
    Frameworks/qgisgrass${VERSION_grass_major}.framework/Versions/$QGIS_VERSION/qgisgrass${VERSION_grass_major} \
    $HANA_PROVIDER \
    $ORACLE_PROVIDER \
    $PDALPROVIDER \
    PlugIns/qgis/libgeometrycheckerplugin.so \
    PlugIns/qgis/libdb2provider.so \
    PlugIns/qgis/libidentcertauthmethod.so \
    PlugIns/qgis/libtopolplugin.so \
    PlugIns/qgis/libgpxprovider.so \
    PlugIns/qgis/libesritokenauthmethod.so \
    PlugIns/qgis/libpostgresrasterprovider.so \
    PlugIns/qgis/libwcsprovider.so \
    PlugIns/qgis/libmdalprovider.so \
    PlugIns/qgis/libdelimitedtextprovider.so \
    PlugIns/qgis/libgpsimporterplugin.so \
    PlugIns/qgis/libspatialiteprovider.so \
    PlugIns/qgis/libgeonodeprovider.so \
    PlugIns/qgis/libgrassrasterprovider${VERSION_grass_major}.so \
    PlugIns/qgis/libwfsprovider.so \
    PlugIns/qgis/liboauth2authmethod.so \
    PlugIns/qgis/libbasicauthmethod.so \
    PlugIns/qgis/libarcgisfeatureserverprovider.so \
    PlugIns/qgis/libowsprovider.so \
    PlugIns/qgis/libpkipathsauthmethod.so \
    PlugIns/qgis/libwmsprovider.so \
    PlugIns/qgis/libofflineeditingplugin.so \
    PlugIns/qgis/libpkcs12authmethod.so \
    PlugIns/qgis/libgrassprovider${VERSION_grass_major}.so \
    PlugIns/qgis/libmssqlprovider.so \
    PlugIns/qgis/libarcgismapserverprovider.so \
    PlugIns/qgis/libpostgresprovider.so \
    PlugIns/qgis/libgrassplugin${VERSION_grass_major}.so \
    PlugIns/qgis/libvirtuallayerprovider.so \
    Resources/python/qgis/_core.so \
    Resources/python/qgis/_3d.so \
    Resources/python/qgis/_server.so \
    Resources/python/qgis/_analysis.so \
    Resources/python/qgis/_gui.so \
    MacOS/lib/libqgis_app.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib \
    MacOS/lib/libqgispython.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib \
    MacOS/lib/libqgis_server.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib \
    PlugIns/designer/libqgis_customwidgets.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib \
    MacOS/lib/qgis/grass/modules/qgis.d.rast7 \
    MacOS/lib/qgis/grass/modules/qgis.g.info7 \
    MacOS/lib/qgis/grass/modules/qgis.r.in7 \
    MacOS/lib/qgis/grass/modules/qgis.v.in7
 do
    for j in \
      $LINK_exiv2 \
      $LINK_expat \
      $LINK_gdal \
      $LINK_libgeos_c \
      $LINK_libgsl \
      $LINK_libgslcblas \
      $LINK_libzip \
      $LINK_libproj \
      $LINK_protobuf_lite \
      $LINK_libpq \
      $LINK_libqscintilla2_qt5 \
      $LINK_qtkeychain \
      $LINK_spatialindex \
      $LINK_spatialite \
      $LINK_sqlite \
      $LINK_zlib \
      $LINK_libtasn1 \
      $LINK_python \
      $LINK_libhdf5 \
      $LINK_libxml2 \
      $LINK_netcdf \
      $LINK_fastcgi
    do
      install_name_change $DEPS_LIB_DIR/$j @rpath/$j $BUNDLE_CONTENTS_DIR/$i
    done

    if [[ "$WITH_PDAL" == "true" ]]; then
      for j in \
        $LINK_zstd \
        $LINK_libpdalcpp \
        $LINK_libpdal_util
      do
        install_name_change $DEPS_LIB_DIR/$j @rpath/$j $BUNDLE_CONTENTS_DIR/$i
      done
    fi

    for j in \
      libgrass_gis \
      libgrass_vector \
      libgrass_raster \
      libgrass_imagery \
      libgrass_dbmibase \
      libgrass_dbmiclient \
      libgrass_gproj \
      libgrass_datetime
    do
      install_name_change $DEPS_GRASS_LIB_DIR/$j.${VERSION_grass_major}.${VERSION_grass_minor}.dylib @rpath/$j.${VERSION_grass_major}.${VERSION_grass_minor}.dylib $BUNDLE_CONTENTS_DIR/$i
    done

    install_name_change $QGIS_BUILD_DIR/output/lib/libqgis_app.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib @rpath/libqgis_app.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/$i
    install_name_change $QGIS_BUILD_DIR/output/lib/libqgispython.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib @rpath/libqgispython.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/$i
    install_name_change $DEPS_LIB_DIR/$LINK_qca.framework/Versions/${VERSION_qca}/$LINK_qca @rpath/$LINK_qca.framework/Versions/${VERSION_qca}/$LINK_qca $BUNDLE_CONTENTS_DIR/$i
    install_name_change $QGIS_BUILD_DIR/output/lib/libqgis_server.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib @rpath/libqgis_server.$QGIS_MAJOR_VERSION.$QGIS_MINOR_VERSION.$QGIS_PATCH_VERSION.dylib $BUNDLE_CONTENTS_DIR/$i

    for j in \
      qgis_core \
      qgis_gui \
      qgis_native \
      qgis_3d \
      qgis_analysis \
      qgisgrass${VERSION_grass_major}
    do
      install_name_id @rpath/$j.framework/Versions/$QGIS_VERSION/$j $BUNDLE_CONTENTS_DIR/Frameworks/$j.framework/Versions/$QGIS_VERSION/$j
      install_name_change $QGIS_BUILD_DIR/output/lib/$j.framework/Versions/$QGIS_VERSION/$j @rpath/$j.framework/Versions/$QGIS_VERSION/$j $BUNDLE_CONTENTS_DIR/$i
    done
 done

 for j in \
    $BUNDLE_CONTENTS_DIR/MacOS/QGIS \
    $BUNDLE_CONTENTS_DIR/Frameworks/qgis_core.framework/Versions/$QGIS_VERSION/qgis_core \
    $BUNDLE_CONTENTS_DIR/Frameworks/qgisgrass7.framework/Versions/$QGIS_VERSION/qgisgrass7
 do
   clean_binary $j
 done

 ## ORACLE
  if [[ "$WITH_ORACLE" == "true" ]]; then
    install_name_id @rpath/PlugIns/sqldrivers/libqsqlocispatial.dylib $BUNDLE_PLUGINS_DIR/sqldrivers/libqsqlocispatial.dylib
    install_name_add_rpath @loader_path/../../Frameworks $BUNDLE_PLUGINS_DIR/sqldrivers/libqsqlocispatial.dylib
    install_name_add_rpath @loader_path/../../MacOS/lib $BUNDLE_PLUGINS_DIR/sqldrivers/libqsqlocispatial.dylib
  fi
}

function fix_binaries_qgis_check() {
  verify_binary $BUNDLE_CONTENTS_DIR/MacOS/QGIS
  verify_binary $BUNDLE_CONTENTS_DIR/Frameworks/qgis_core.framework/Versions/$QGIS_VERSION/qgis_core
  verify_binary $BUNDLE_CONTENTS_DIR/PlugIns/qgis/libdb2provider.so

  ## ORACLE
  if [[ "$WITH_ORACLE" == "true" ]]; then
    verify_binary $BUNDLE_PLUGINS_DIR/sqldrivers/libqsqlocispatial.dylib
    verify_binary $BUNDLE_LIB_DIR/libclntsh.dylib
  fi
}

function fix_paths_qgis() {
 ###################
 # Patch Info.plist
 /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string $MACOSX_DEPLOYMENT_TARGET" $BUNDLE_CONTENTS_DIR/Info.plist
 /usr/libexec/PlistBuddy -c "Add :LSFileQuarantineEnabled bool false" $BUNDLE_CONTENTS_DIR/Info.plist
 # PYQGIS_STARTUP should be relative to Contents/Resources/python
 /usr/libexec/PlistBuddy -c "Add :LSEnvironment:PYQGIS_STARTUP string pyqgis-startup.py" $BUNDLE_CONTENTS_DIR/Info.plist
 # PROJ_LIB see ../proj/recipe.sh
 # GDAL_DATA and GDAL_DRIVER_PATH see ../gdal/recipe.sh
 # PYTHONHOME see ../python/recipe.sh

 #####################
 # utils.py
 try ${SED} "s@import sqlite3@import sqlite3;from .find_mod_spatialite import mod_spatialite_path@g" $BUNDLE_RESOURCES_DIR/python/qgis/utils.py
 try ${SED} "s@\"mod_spatialite\"@mod_spatialite_path()@g" $BUNDLE_RESOURCES_DIR/python/qgis/utils.py
}

function fix_paths_qgis_check() {
  :
}

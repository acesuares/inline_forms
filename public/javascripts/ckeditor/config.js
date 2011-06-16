/*
Copyright (c) 2003-2011, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
    config.PreserveSessionOnFileBrowser = true;

    config.language = 'nl';

    config.height = '400px';
    config.width = '600px';

    config.toolbar = 'Minimal';

    config.toolbarCanCollapse = false;

    config.toolbar_Minimal =
        [
            ['Format','-','Bold','Italic','-','NumberedList','BulletedList','-','Link'],
            ['PasteFromWord','Source','Undo','Redo','RemoveFormat'],
        ];

    config.toolbar_None =
        [ '-' ];

};

/*
Copyright (c) 2003-2011, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
    // Define changes to default configuration here. For example:
    // config.language = 'fr';
    // config.uiColor = '#AADC6E';
	
    /* Filebrowser routes */
    // The location of an external file browser, that should be launched when "Browse Server" button is pressed.
    config.filebrowserBrowseUrl = "/ckeditor/attachment_files";

    // The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Flash dialog.
    config.filebrowserFlashBrowseUrl = "/ckeditor/attachment_files";

    // The location of a script that handles file uploads in the Flash dialog.
    config.filebrowserFlashUploadUrl = "/ckeditor/attachment_files";
  
    // The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Link tab of Image dialog.
    config.filebrowserImageBrowseLinkUrl = "/ckeditor/pictures";

    // The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Image dialog.
    config.filebrowserImageBrowseUrl = "/ckeditor/pictures";

    // The location of a script that handles file uploads in the Image dialog.
    var token = $('meta[name=csrf-token]').attr('content');
    var param = $('meta[name=csrf-param]').attr('content');
    config.filebrowserImageUploadUrl = "/ckeditor/pictures" + "?" + token + "=" + param;
    // The location of a script that handles file uploads.
    config.filebrowserUploadUrl = "/ckeditor/attachment_files";
  
    // Rails CSRF token
    config.filebrowserParams = function(){
        var csrf_token = $('meta[name=csrf-token]').attr('content'),
        csrf_param = $('meta[name=csrf-param]').attr('content'),
        params = new Object();
    
        if (csrf_param !== undefined && csrf_token !== undefined) {
            params[csrf_param] = csrf_token;
        }
    
        return params;
    };
  
    /* Extra plugins */
    // works only with en, ru, uk locales
//    config.extraPlugins = "embed,attachment";

    config.height = 400;
    config.width = 600;



    config.language = 'nl';

    /* Toolbars */

    config.toolbarCanCollapse = false;

    config.toolbar_Minimal =
    [
    ['Format','-','Bold','Italic','-','NumberedList','BulletedList','-','Link'],
    ['PasteFromWord','Source','Undo','Redo','RemoveFormat'],
    ];

    config.toolbar_None =
    [ '-' ];

    config.toolbar = 'Minimal';

};

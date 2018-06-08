/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
/**
 * Before executing the batch job to retrieve DocumentFolder metadata,
 * ask user which Library Permission to assign to users who had:
 *      1. Read Only access to a folder
 *      2. Read/Write access to a folder
 *
 * Although library members can have multiple permissions, and different
 * permissions per library, this conversion tool is not designed for library management.
 * Once the Document Folders are converted to Libraries and the Documents converted to Files,
 * then an administrator may further refine library member permissions as desired.
 *
 * Learn more about library management at:
 *      https://help.salesforce.com/articleView?id=collab_files_library_folders.htm
 *      https://help.salesforce.com/articleView?id=collab_admin_content_libraries.htm&type=5
 *      https://trailhead.salesforce.com/modules/lightning-experience-productivity/units/work-with-notes-and-files
 */

public without sharing class Doc2File_PrepareFoldersBatchable implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    // I got tired of adding new constructor arguments
    // every time I thought of a new option to support
    public class Options {

        // To authenticate to metadata api
        public String namedCredential { get; set; }

        // Permission to grant members
        // for the library created for a folder with read only public access
        public ID readOnlyLibraryPermissionId { get; set; }

        // Permission to grant members
        // for the library created for a folder with read/write public access
        public ID readWriteLibraryPermissionId { get; set; }

        // Specify one or more document folder ids to
        // scope the conversion, leave empty to convert all folders
        public Set<ID> documentFolderIds { get; set; }

        public override String toString() {
            return (
                'Options:{' +
                    'namedCredential=' + this.namedCredential + ', ' +
                    'readOnlyLibraryPermissionId=' + this.readOnlyLibraryPermissionId + ', ' +
                    'readWriteLibraryPermissionId=' + this.readWriteLibraryPermissionId + ', ' +
                    'documentFolderIds=' + this.documentFolderIds +
                '}'
            );
        }

    }

    private Options options { get; set; }

    public Doc2File_PrepareFoldersBatchable( Options options ) {
        this.options = options;
    }

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Doc2File_PrepareFoldersBatchable.start: ' + context );
        System.debug( options );

        // Hidden folders are not included as those are private to individual users
        // and Salesforce limits of 2,000 libraries won't sustain 1+ libraries per user.
        // Instead, users can use a visualforce page to convert documents in their hidden
        // folders to files that will be saved to their private library.

        if ( this.options.documentFolderIds == null || this.options.documentFolderIds.isEmpty() ) {

            return Database.getQueryLocator([
                SELECT
                    Id,
                    Name,
                    DeveloperName,
                    AccessType,
                    Type
                FROM
                    Folder
                WHERE
                    Type = 'Document'
                    AND
                    AccessType IN ( 'Shared', 'Public' )
                ORDER BY
                    Name,
                    Id
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    Id,
                    Name,
                    DeveloperName,
                    AccessType,
                    Type
                FROM
                    Folder
                WHERE
                    Type = 'Document'
                    AND
                    Id IN :this.options.documentFolderIds
                ORDER BY
                    Name,
                    Id
            ]);

        }

    }

    public void execute( Database.BatchableContext context, List<Folder> folders ) {

        System.debug( 'Doc2File_PrepareFoldersBatchable.execute: ' + context );

        SavePoint sp = Database.setSavepoint();

        try {

            Doc2File_FolderConversionService service = new Doc2File_FolderConversionService();

            service.prepareDocumentFoldersForConversion( folders, this.options.namedCredential, this.options.readOnlyLibraryPermissionId, this.options.readWriteLibraryPermissionId );

        } catch ( Exception e ) {

            Database.rollback( sp );

            System.debug( LoggingLevel.ERROR, e );

            // todo create doc2file_log__c

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Doc2File_PrepareFoldersBatchable.finish: ' + context );

        // todo send progress update email that document folders and membership analysis done, starting job to create libraries

        Database.executeBatch( new Doc2File_CreateLibrariesBatchable() );

    }

}
/*
BSD 3-Clause License

Copyright (c) 2018, Doug Ayers, douglascayers.com
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
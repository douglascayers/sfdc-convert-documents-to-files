/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdx-convert-documents-to-files
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
public without sharing class Doc2File_GetFolderMetadataBatchable implements Database.Batchable<Folder>, Database.Stateful, Database.AllowsCallouts {

    private String namedCredentialName { get; set; }

    private ID readOnlyLibraryPermissionId { get; set; }

    private ID readWriteLibraryPermissionId { get; set; }

    public Doc2File_GetFolderMetadataBatchable( String namedCredentialName, ID readOnlyLibraryPermissionId, ID readWriteLibraryPermissionId ) {
        this.namedCredentialName = namedCredentialName;
        this.readOnlyLibraryPermissionId = readOnlyLibraryPermissionId;
        this.readWriteLibraryPermissionId = readWriteLibraryPermissionId;
    }

    public List<Folder> start( Database.BatchableContext context ) {

        System.debug( 'Doc2File_GetFolderMetadataBatchable.start: ' + context );
        System.debug( 'namedCredential=' + this.namedCredentialName );
        System.debug( 'readOnlyLibraryPermissionId=' + this.readOnlyLibraryPermissionId );
        System.debug( 'readWriteLibraryPermissionId=' + this.readWriteLibraryPermissionId );

        return [
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
        ];
    }

    public void execute( Database.BatchableContext context, List<Folder> folders ) {

        System.debug( 'Doc2File_GetFolderMetadataBatchable.execute: ' + context );

        Map<String, String> publicAccessLibraryPermissionMap = new Map<String, String> {
            'ReadOnly' => this.readOnlyLibraryPermissionId,
            'ReadWrite' => this.readWriteLibraryPermissionId
        };

        Map<ID, Folder> foldersByIdsMap = new Map<ID, Folder>( folders );
        Map<String, Folder> foldersByNamesMap = (Map<String, Folder>) Doc2File_SObjectUtils.toMapByKeyField( Folder.DeveloperName, folders );

        // Optimistically, we'll assume we are to convert every folder provided to us.
        // In the next step, we'll remove any folder names that have already been, or marked to be, converted.
        Set<String> folderDeveloperNamesToConvert = new Set<String>( foldersByNamesMap.keySet() );

        // Check that we haven't already converted the folder.
        // To convert a folder again, you must first delete the
        // matching Convert_Document_Folder_to_Library__c record.
        for ( Convert_Document_Folder_to_Library__c convertedFolder : [
            SELECT
                Id,
                Folder_ID__c
            FROM
                Convert_Document_Folder_to_Library__c
            WHERE
                Folder_ID__c IN :foldersByIdsMap.keySet()
        ]) {
            Folder f = foldersByIdsMap.get( convertedFolder.Folder_ID__c );
            folderDeveloperNamesToConvert.remove( f.DeveloperName );
            System.debug( LoggingLevel.WARN, 'Document Folder "' + f.DeveloperName + '" has, or is marked to be, converted to a Library. To enqueue folder and its documents to be converted again, delete Convert_Document_Folder_to_Library__c record ' + convertedFolder.Id );
        }

        if ( folderDeveloperNamesToConvert.size() > 0 ) {

            Doc2File_DocumentFolderService folderService = new Doc2File_DocumentFolderService( this.namedCredentialName );

            List<Doc2File_DocumentFolderService.DocumentFolderMembership> folderMemberships = folderService.getDocumentFolderMembership( folderDeveloperNamesToConvert );

            List<Convert_Document_Folder_to_Library__c> folders2libraries = new List<Convert_Document_Folder_to_Library__c>();

            for ( Doc2File_DocumentFolderService.DocumentFolderMembership folderMembership : folderMemberships ) {

                folders2libraries.add( new Convert_Document_Folder_to_Library__c(
                    Folder_ID__c = foldersByNamesMap.get( folderMembership.folderDeveloperName ).Id,
                    Group_IDs__c = String.join( folderMembership.getAllGroupIds(), ',' ),
                    Library_Permission_ID__c = publicAccessLibraryPermissionMap.get( folderMembership.publicFolderAccess )
                ));

            }

            insert folders2libraries;

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Doc2File_GetFolderMetadataBatchable.finish: ' + context );

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
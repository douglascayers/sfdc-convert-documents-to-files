/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public class Doc2File_FolderConversionService {

    public void prepareDocumentFoldersForConversion( List<Folder> folders, String namedCredential, ID readOnlyLibraryPermissionId, ID readWriteLibraryPermissionId ) {

        Map<String, String> publicAccessLibraryPermissionMap = new Map<String, String> {
            'ReadOnly' => readOnlyLibraryPermissionId,
            'ReadWrite' => readWriteLibraryPermissionId
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

            Doc2File_DocumentFolderService folderService = new Doc2File_DocumentFolderService( namedCredential );

            List<Doc2File_DocumentFolderService.DocumentFolderMembership> folderMemberships = folderService.getDocumentFolderMembership( folderDeveloperNamesToConvert );

            List<Convert_Document_Folder_to_Library__c> folders2libraries = new List<Convert_Document_Folder_to_Library__c>();

            for ( Doc2File_DocumentFolderService.DocumentFolderMembership folderMembership : folderMemberships ) {

                folders2libraries.add( new Convert_Document_Folder_to_Library__c(
                    Folder_ID__c = foldersByNamesMap.get( folderMembership.folderDeveloperName ).Id,
                    Folder_Name__c = folderMembership.folderName,
                    Folder_Developer_Name__c = folderMembership.folderDeveloperName,
                    Group_IDs__c = String.join( folderMembership.getAllGroupIds(), ',' ),
                    Library_Permission_ID__c = publicAccessLibraryPermissionMap.get( folderMembership.publicFolderAccess )
                ));

            }

            insert folders2libraries;

        }

    }

    public void createLibrariesForDocumentFolders( List<Convert_Document_Folder_to_Library__c> folders2libraries ) {

        // ContentWorkspaceMember.MemberId must be a User ID or Public Group ID,
        // but the Group IDs derived from Document Folder shares could be roles, role and subordinates, etc.
        // So to ensure the new library has same membership as the document folder it is based on,
        // then we must create a public group whose members are the same as the document folder's shares.
        // Then we can add this new public group as the new library's membership.

        // These are all system objects and their DML can occur in the same transaction.
        // Creating and adding files to the library must occur in a separate batch job.

        Map<String, Group> groupNamesMap = new Map<String, Group>();
        Map<String, ContentWorkspace> libraryNamesMap = new Map<String, contentWorkspace>();

        for ( Convert_Document_Folder_to_Library__c folder2library : folders2libraries ) {

            String libraryDeveloperName = buildLibraryDeveloperName( folder2library.Folder_Developer_Name__c );

            // TODO query and re-use existing groups with same developer name
            // TODO handle field max length
            Group grp = new Group(
                Name = 'Library: ' + folder2library.Folder_Name__c,
                DeveloperName = libraryDeveloperName,
                Type = 'Regular'
            );
            groupNamesMap.put( grp.DeveloperName, grp );

            // TODO query and re-use existing libraries with same developer name
            // TODO handle field max length
            ContentWorkspace library = new ContentWorkspace(
                Name = folder2library.Folder_Name__c,
                DeveloperName = libraryDeveloperName,
                ShouldAddCreatorMembership = true
            );
            libraryNamesMap.put( library.DeveloperName, library );

        }

        insert groupNamesMap.values();
        insert libraryNamesMap.values();

        List<GroupMember> groupMembers = new List<GroupMember>();
        List<ContentWorkspaceMember> libraryMembers = new List<ContentWorkspaceMember>();

        for ( Convert_Document_Folder_to_Library__c folder2library : folders2libraries ) {

            // TODO only add members if created a new library

            String libraryDeveloperName = buildLibraryDeveloperName( folder2library.Folder_Developer_Name__c );

            ID libraryGroupId = groupNamesMap.get( libraryDeveloperName ).Id;
            ID libraryId = libraryNamesMap.get( libraryDeveloperName ).Id;

            if ( String.isNotBlank( folder2library.Group_IDs__c ) ) {
                for ( String groupId : folder2library.Group_IDs__c.split( ',' ) ) {
                    groupMembers.add( new GroupMember(
                        GroupId = libraryGroupId,
                        UserOrGroupId = groupId
                    ));
                }
            }

            libraryMembers.add( new ContentWorkspaceMember(
                ContentWorkspaceId = libraryId,
                ContentWorkspacePermissionId = folder2library.Library_Permission_ID__c,
                MemberId = libraryGroupId
            ));

        }

        insert groupMembers;
        insert libraryMembers;

    }

    public void convertDocumentsToFiles( List<Document> documents ) {

        Set<ID> documentIds = new Set<ID>();
        Set<ID> folderIds = new Set<ID>();
        for ( Document doc : documents ) {
            documentIds.add( doc.Id );
            folderIds.add( doc.FolderId );
        }

        Set<String> libraryNames = new Set<String>();
        Map<ID, Folder> foldersMap = new Map<ID, Folder>([ SELECT Id, Name, DeveloperName FROM Folder WHERE Id IN :folderIds ]);
        for ( Folder f : foldersMap.values() ) {
            libraryNames.add( buildLibraryDeveloperName( f.DeveloperName ) );
        }

        Map<ID, ContentWorkspace> librariesMap = new Map<ID, ContentWorkspace>([ SELECT Id, Name, DeveloperName FROM ContentWorkspace WHERE DeveloperName IN :libraryNames ]);
        Map<String, ContentWorkspace> libraryNamesMap = Doc2File_SObjectUtils.toMapByKeyField( ContentWorkspace.DeveloperName, librariesMap.values() );

        Map<ID, ID> alreadyConvertedDocumentIdsMap = getAlreadyConvertedDocumentIdsMap( documentIds, librariesMap.keySet() );

        // todo add error handling and logging like in ConvertAttachmentsToFilesService.cls
        List<ContentVersion> newFileVersions = new List<ContentVersion>();

        for ( Document doc : documents ) {

            if ( alreadyConvertedDocumentIdsMap.containsKey( doc.Id ) ) {
                System.debug( 'Document has already been converted, skipping... ' + doc );
                continue;
            }

            Folder f = foldersMap.get( doc.FolderId );
            String libraryName = buildLibraryDeveloperName( f.DeveloperName );
            ContentWorkspace library = libraryNamesMap.get( libraryName );

            if ( doc.Type == 'URL' ) {

                newFileVersions.add( new ContentVersion(
                    // data fields
                    ContentUrl = doc.Url,
                    Title = doc.Name,
                    Description = doc.Description,
                    FirstPublishLocationId = library.Id,
                    TagCsv = doc.Keywords,
                    // audit fields
                    OwnerId = doc.AuthorId, // system requirement, owner and creator must be the same
                    CreatedById = doc.AuthorId,
                    CreatedDate = doc.CreatedDate,
                    LastModifiedById = doc.LastModifiedById,
                    LastModifiedDate = doc.LastModifiedDate,
                    // custom fields for history tracking and conversion purposes
                    Original_Record_ID__c = doc.Id,
                    Original_Record_Parent_ID__c = f.Id
                ));

            } else {

                newFileVersions.add( new ContentVersion(
                    // data fields
                    VersionData = doc.Body,
                    PathOnClient = '/' + doc.DeveloperName + '.' + doc.Type,
                    Title = doc.Name,
                    Description = doc.Description,
                    FirstPublishLocationId = library.Id,
                    TagCsv = doc.Keywords,
                    // audit fields
                    OwnerId = doc.AuthorId, // system requirement, owner and creator must be the same
                    CreatedById = doc.AuthorId,
                    CreatedDate = doc.CreatedDate,
                    LastModifiedById = doc.LastModifiedById,
                    LastModifiedDate = doc.LastModifiedDate,
                    // custom fields for history tracking and conversion purposes
                    Original_Record_ID__c = doc.Id,
                    Original_Record_Parent_ID__c = f.Id
                ));

            }

            // todo handle if document belonged to library that was accessible to all users
            // did that include portal users??
            // how can library be shared to all users??

        }

        insert newFileVersions;

    }

    // -----------------------------------------------------------------

    /**
     * Given a list of Documents then returns the submap of those
     * that have already been converted and their new file ids.
     */
    public Map<ID, ID> getAlreadyConvertedDocumentIdsMap( Set<ID> documentIds, Set<ID> libraryIds ) {

        // map of old Document ids to new file ids
        Map<ID, ID> convertedDocumentIdsMap = new Map<ID, ID>();

        for ( List<ContentDocumentLink> links : [
            SELECT
                ContentDocument.LatestPublishedVersionId,
                ContentDocument.LatestPublishedVersion.Original_Record_ID__c
            FROM
                ContentDocumentLink
            WHERE
                LinkedEntityId IN :libraryIds
                AND
                ContentDocument.LatestPublishedVersion.Original_Record_ID__c IN :documentIds
        ]) {

            for ( ContentDocumentLink link : links ) {

                if ( link.ContentDocument != null && link.ContentDocument.LatestPublishedVersion != null ) {

                    if ( documentIds.contains( link.ContentDocument.LatestPublishedVersion.Original_Record_ID__c ) ) {
                        convertedDocumentIdsMap.put( link.ContentDocument.LatestPublishedVersion.Original_Record_ID__c, link.ContentDocument.LatestPublishedVersionId );
                    }

                }

            }

        }

        return convertedDocumentIdsMap;
    }

    // -----------------------------------------------------

    private String buildLibraryDeveloperName( String folderDeveloperName ) {
        return 'doc2file_' + folderDeveloperName;
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
/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public class Doc2File_FolderConversionService {

    /**
     * Saves Doc2File_Request__c request records to indicate
     * the given document folders and their documents should be
     * converted to libraries and files.
     *
     * @param folders
     *      Expects each folder record to have these fields populated: Id, DeveloperName
     * @param namedCredential
     *      For calling Metadata API to determine to what roles and groups a folder is shared
     * @param readOnlyLibraryPermissionId
     *      If a folder's public access is read only, what library persmission to grant members?
     * @param readWriteLibraryPermissionId
     *      If a folder's public access is read/write, what library permission to grant members?
     *
     * @return conversion results with status of either QUEUED, ERROR, or SKIPPED
     */
    public List<ConversionResult> prepareDocumentFoldersForConversion( List<Folder> folders, String namedCredential, ID readOnlyLibraryPermissionId, ID readWriteLibraryPermissionId ) {

        System.debug( 'Doc2File_FolderConversionService.prepareDocumentFoldersForConversion' );

        Map<ID, DocumentFolderConversionResult> conversionResultsByFolderIdsMap = initConversionResultByDocumentFolderIdMap( folders );

        List<Doc2File_Request__c> foldersToConvert = buildDocumentFolderConversionRequests( folders, namedCredential, readOnlyLibraryPermissionId, readWriteLibraryPermissionId, conversionResultsByFolderIdsMap );

        insertDocumentFolderConversionRequests( foldersToConvert, conversionResultsByFolderIdsMap );

        // Ensure returned list of results is same order as the folders parameter.
        // This is common convention among apex DML operations.
        List<ConversionResult> conversionResults = new List<ConversionResult>();
        for ( Folder f : folders ) {
            conversionResults.add( conversionResultsByFolderIdsMap.get( f.Id ) );
        }

        return conversionResults;
    }

    private List<Doc2File_Request__c> buildDocumentFolderConversionRequests( List<Folder> folders, String namedCredential, ID readOnlyLibraryPermissionId, ID readWriteLibraryPermissionId, Map<ID, DocumentFolderConversionResult> conversionResultsByFolderIdsMap ) {

        System.debug( 'Doc2File_FolderConversionService.buildDocumentFolderConversionRequests' );

        List<Doc2File_Request__c> folders2libraries = new List<Doc2File_Request__c>();

        Map<String, String> publicAccessLibraryPermissionMap = new Map<String, String> {
            'ReadOnly' => readOnlyLibraryPermissionId,
            'ReadWrite' => readWriteLibraryPermissionId
        };

        // filter to just the document folders that still need to be converted
        Set<String> folderDeveloperNamesToConvert = getDocumentFolderNamesToConvert( folders, conversionResultsByFolderIdsMap );

        if ( folderDeveloperNamesToConvert.size() > 0 ) {

            Doc2File_DocumentFolderService folderService = new Doc2File_DocumentFolderService( namedCredential );

            List<Doc2File_DocumentFolderService.DocumentFolderMembership> folderMemberships = folderService.getDocumentFolderMembership( folderDeveloperNamesToConvert );

            for ( Doc2File_DocumentFolderService.DocumentFolderMembership folderMembership : folderMemberships ) {

                folders2libraries.add( new Doc2File_Request__c(
                    Folder_ID__c = folderMembership.folderId,
                    Folder_Name__c = folderMembership.folderName,
                    Folder_Developer_Name__c = folderMembership.folderDeveloperName,
                    Group_IDs__c = String.join( folderMembership.getAllGroupIds(), ',' ),
                    Library_Permission_ID__c = publicAccessLibraryPermissionMap.get( folderMembership.publicFolderAccess )
                ));

            }

        }

        return folders2libraries;
    }

    private Set<String> getDocumentFolderNamesToConvert( List<Folder> folders, Map<ID, DocumentFolderConversionResult> conversionResultsByFolderIdsMap ) {

        System.debug( 'Doc2File_FolderConversionService.getDocumentFolderNamesToConvert' );

        Map<ID, Folder> foldersByIdsMap = new Map<ID, Folder>( folders );
        Map<String, Folder> foldersByNamesMap = (Map<String, Folder>) Doc2File_SObjectUtils.toMapByKeyField( Folder.DeveloperName, folders );

        // Optimistically, we'll assume we are to convert every folder provided to us.
        // In the next step, we'll remove any folder names that have already been, or marked to be, converted.
        Set<String> folderDeveloperNamesToConvert = new Set<String>( foldersByNamesMap.keySet() );

        // Check that we haven't already converted the folder.
        // To convert a folder again, you must first delete the
        // matching Doc2File_Request__c record.
        for ( Doc2File_Request__c convertedFolder : [
            SELECT
                Id,
                Folder_ID__c
            FROM
                Doc2File_Request__c
            WHERE
                Folder_ID__c IN :foldersByIdsMap.keySet()
        ]) {

            Folder f = foldersByIdsMap.get( convertedFolder.Folder_ID__c );

            folderDeveloperNamesToConvert.remove( f.DeveloperName );

            DocumentFolderConversionResult conversionResult = conversionResultsByFolderIdsMap.get( f.Id );
            conversionResult.status = ConversionResultStatus.SKIPPED;
            conversionResult.messages.add( 'Document Folder "' + f.DeveloperName + '" has, or is marked to be, converted to a Library. To enqueue folder and its documents to be converted again, delete Doc2File_Request__c record ' + convertedFolder.Id );
            conversionResult.documentFolderId = f.Id;

        }

        return folderDeveloperNamesToConvert;
    }

    private void insertDocumentFolderConversionRequests( List<Doc2File_Request__c> requests, Map<ID, DocumentFolderConversionResult> conversionResultsByFolderIdsMap ) {

        Boolean allOrNone = false;

        List<Database.SaveResult> saveResults = Database.insert( requests, allOrNone );

        for ( Integer i = 0; i < saveResults.size(); i++ ) {

            Database.SaveResult saveResult = saveResults[i];

            Doc2File_Request__c request = requests[i];
            ID folderId = request.Folder_ID__c;
            ConversionResult conversionResult = conversionResultsByFolderIdsMap.get( folderId );

            if ( !saveResult.isSuccess() ) {

                for ( Database.Error err : saveResult.getErrors() ) {
                    conversionResult.messages.add( err.getMessage() );
                }

                conversionResult.status = ConversionResultStatus.ERROR;

            } else {

                conversionResult.status = ConversionResultStatus.QUEUED;

            }

        }

    }

    // -----------------------------------------------------

    public void createLibrariesForDocumentFolders( List<Doc2File_Request__c> folders2libraries ) {

        // ContentWorkspaceMember.MemberId must be a User ID or Public Group ID,
        // but the Group IDs derived from Document Folder shares could be roles, role and subordinates, etc.
        // So to ensure the new library has same membership as the document folder it is based on,
        // then we must create a public group whose members are the same as the document folder's shares.
        // Then we can add this new public group as the new library's membership.

        // These are all system objects and their DML can occur in the same transaction.
        // Creating and adding files to the library must occur in a separate batch job.

        // Updating the Doc2File_Request__c records with the generated library id and public group id
        // must also occur in a separate transaction, which is done via platform events.
        List<Doc2File_Request__c> folders2librariesToUpdate = new List<Doc2File_Request__c>();

        Map<String, Group> groupNamesMap = new Map<String, Group>();
        Map<String, ContentWorkspace> libraryNamesMap = new Map<String, contentWorkspace>();

        for ( Doc2File_Request__c folder2library : folders2libraries ) {

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

        for ( Doc2File_Request__c folder2library : folders2libraries ) {

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

            // capture the new library and public group id created
            // for this document folder for tracking purposes
            folders2librariesToUpdate.add( new Doc2File_Request__c(
                Id = folder2library.Id,
                Library_ID__c = libraryId,
                Library_Public_Group_ID__c = libraryGroupId
            ));

        }

        insert groupMembers;
        insert libraryMembers;

        // due to mixed-dml of system and non-system objects,
        // the non-system objects are being updated asynchronously
        EventBus.publish( new Doc2File_Event__e(
            Payload__c = JSON.serialize( folders2librariesToUpdate )
        ));

    }

    // -----------------------------------------------------

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

            // todo log a skipped conversion result like attachment converter project
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

    private Map<ID, DocumentFolderConversionResult> initConversionResultByDocumentFolderIdMap( List<Folder> folders ) {

        Map<ID, DocumentFolderConversionResult> resultMap = new Map<ID, DocumentFolderConversionResult>();

        for ( Folder f : folders ) {

            DocumentFolderConversionResult result = new DocumentFolderConversionResult();
            result.documentFolderId = f.Id;

            resultMap.put( f.Id, result );

        }

        return resultMap;
    }

    // -----------------------------------------------------

    private String buildLibraryDeveloperName( String folderDeveloperName ) {
        return 'Doc2File_' + folderDeveloperName;
    }

    // -----------------------------------------------------

    public abstract class ConversionResult {

        // was conversion success? skipped? error?
        public ConversionResultStatus status { get; set; }

        // any pertinent message
        public Set<String> messages { get; set; }

        public ConversionResult() {
            this.messages = new Set<String>();
        }

    }

    public class DocumentFolderConversionResult extends ConversionResult {

        // id of the document folder to convert
        public ID documentFolderId { get; set; }

    }

    public class DocumentConversionResult extends ConversionResult {

        // id of the document to convert
        public ID documentId { get; set; }

    }

    public enum ConversionResultStatus {
        QUEUED, CONVERTED, SKIPPED, ERROR
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
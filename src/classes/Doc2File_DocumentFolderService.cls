/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public class Doc2File_DocumentFolderService {

    private String namedCredential { get; set; }

    public Doc2File_DocumentFolderService( String namedCredential ) {
        this.namedCredential = namedCredential;
    }

    public List<DocumentFolderMembership> getDocumentFolderMembership( Set<String> folderDeveloperNames ) {

        List<DocumentFolderMembership> folderMemberships = new List<DocumentFolderMembership>();
        Map<String, DocumentFolderMembership> folderMembershipMap = new Map<String, DocumentFolderMembership>();

        MetadataService.ReadDocumentFolderResult folderResult = getDocumentFolderMetadata( new List<String>( folderDeveloperNames ) );

        // Each folder result metadata has sharedTo properties of the
        // public groups and roles the folder is shared with.
        // These are the group/role names from all the folders.
        // They are used to make soql queries later.
        Set<String> groupNames = new Set<String>();
        Set<String> portalRoleNames = new Set<String>();
        Set<String> portalRoleAndSubordinatesNames = new Set<String>();
        Set<String> roleNames = new Set<String>();
        Set<String> roleAndSubordinatesNames = new Set<String>();
        Set<String> roleAndSubordinatesInternalNames = new Set<String>();

        // In this first loop,
        // we copy over metadata properties to our custom apex object, DocumentFolderMembership,
        // and populate set variables for use as soql bind variables later
        for ( MetadataService.DocumentFolder folder : folderResult.records ) {

            DocumentFolderMembership folderMembership = new DocumentFolderMembership();
            folderMembershipMap.put( folder.fullName, folderMembership );

            folderMembership.folderName = folder.name;
            folderMembership.folderDeveloperName = folder.fullName;
            folderMembership.accessType = folder.accessType;
            folderMembership.publicFolderAccess = folder.publicFolderAccess;

            if ( folder.sharedTo != null ) {

                if ( folder.sharedTo.group_x != null ) {
                    folderMembership.sharedToPublicGroupIds = new List<ID>();
                    folderMembership.sharedToPublicGroupNames = new List<String>( folder.sharedTo.group_x );
                    groupNames.addAll( folder.sharedTo.group_x );
                }

                if ( folder.sharedTo.portalRole != null ) {
                    folderMembership.sharedToPortalRoleIds = new List<ID>();
                    folderMembership.sharedToPortalRoleNames = new List<String>( folder.sharedTo.portalRole );
                    portalRoleNames.addAll( folder.sharedTo.portalRole );
                }

                if ( folder.sharedTo.portalRoleAndSubordinates != null ) {
                    folderMembership.sharedToPortalRoleAndSubordinatesIds = new List<ID>();
                    folderMembership.sharedToPortalRoleAndSubordinatesNames = new List<String>( folder.sharedTo.portalRoleAndSubordinates );
                    portalRoleAndSubordinatesNames.addAll( folder.sharedTo.portalRoleAndSubordinates );
                }

                if ( folder.sharedTo.role != null ) {
                    folderMembership.sharedToRoleIds = new List<ID>();
                    folderMembership.sharedToRoleNames = new List<String>( folder.sharedTo.role );
                    roleNames.addAll( folder.sharedTo.role );
                }

                if ( folder.sharedTo.roleAndSubordinates != null ) {
                    folderMembership.sharedToRoleAndSubordinatesIds = new List<ID>();
                    folderMembership.sharedToRoleAndSubordinatesNames = new List<String>( folder.sharedTo.roleAndSubordinates );
                    roleAndSubordinatesNames.addAll( folder.sharedTo.roleAndSubordinates );
                }

                if ( folder.sharedTo.roleAndSubordinatesInternal != null ) {
                    folderMembership.sharedToRoleAndSubordinatesInternalIds = new List<ID>();
                    folderMembership.sharedToRoleAndSubordinatesInternalNames = new List<String>( folder.sharedTo.roleAndSubordinatesInternal );
                    roleAndSubordinatesInternalNames.addAll( folder.sharedTo.roleAndSubordinatesInternal );
                }

            }

        }

        // Using the group/role name sets populated in the first loop above,
        // now query for the Group records and create maps indexed by their developer names.
        // These maps let us cross-reference the group/role names to their ids.
        Map<String, Group> publicAccessNamesMap = toMapByDeveloperName( getGroupsByDeveloperName( new Set<String>{ 'AllInternalUsers', 'AllPartnerUsers', 'AllCustomerPortalUsers' } ) );
        Map<String, Group> groupNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( groupNames, 'Regular' ) );
        Map<String, Group> portalRoleNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( portalRoleNames, 'Role' ) );
        Map<String, Group> portalRoleAndSubordinatesNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( portalRoleAndSubordinatesNames, 'RoleAndSubordinates' ) );
        Map<String, Group> roleNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( roleNames, 'Role' ) );
        Map<String, Group> roleAndSubordinatesNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( roleAndSubordinatesNames, 'RoleAndSubordinates' ) );
        Map<String, Group> roleAndSubordinatesInternalNamesMap = toMapByDeveloperName( getGroupsByDeveloperNameAndType( roleAndSubordinatesInternalNames, 'RoleAndSubordinatesInternal' ) );

        // In this second loop,
        // lookup the group/role ids by their name and copy them to our custom apex object, DocumentFolderMembership.
        for ( MetadataService.DocumentFolder folder : folderResult.records ) {

            DocumentFolderMembership folderMembership = folderMembershipMap.get( folder.fullName );

            if ( folder.accessType != null ) {

                if ( folder.accessType == 'Public' ) {

                    folderMembership.publicAccessGroupNames = new List<String>( publicAccessNamesMap.keySet() );
                    folderMembership.publicAccessGroupIds = new List<String>();
                    for ( String key : publicAccessNamesMap.keySet() ) {
                        folderMembership.publicAccessGroupIds.add( publicAccessNamesMap.get( key ).Id );
                    }

                } else if ( folder.accessType == 'PublicInternal' ) {

                    folderMembership.publicAccessGroupNames = new List<String>{ 'AllInternalUsers' };
                    folderMembership.publicAccessGroupIds = new List<String>{ publicAccessNamesMap.get( 'AllInternalUsers' ).Id };

                }

            }

            if ( folder.sharedTo != null ) {

                if ( folder.sharedTo.group_x != null ) {
                    for ( String name : folder.sharedTo.group_x ) {
                        folderMembership.sharedToPublicGroupIds.add( groupNamesMap.get( name ).Id );
                    }
                }

                if ( folder.sharedTo.portalRole != null ) {
                    for ( String name : folder.sharedTo.portalRole ) {
                        folderMembership.sharedToPortalRoleIds.add( portalRoleNamesMap.get( name ).Id );
                    }
                }

                if ( folder.sharedTo.portalRoleAndSubordinates != null ) {
                    for ( String name : folder.sharedTo.portalRoleAndSubordinates ) {
                        folderMembership.sharedToPortalRoleAndSubordinatesIds.add( portalRoleAndSubordinatesNamesMap.get( name ).Id );
                    }
                }

                if ( folder.sharedTo.role != null ) {
                    for ( String name : folder.sharedTo.role ) {
                        folderMembership.sharedToRoleIds.add( roleNamesMap.get( name ).Id );
                    }
                }

                if ( folder.sharedTo.roleAndSubordinates != null ) {
                    for ( String name : folder.sharedTo.roleAndSubordinates ) {
                        folderMembership.sharedToRoleAndSubordinatesIds.add( roleAndSubordinatesNamesMap.get( name ).Id );
                    }
                }

                if ( folder.sharedTo.roleAndSubordinatesInternal != null ) {
                    for ( String name : folder.sharedTo.roleAndSubordinatesInternal ) {
                        folderMembership.sharedToRoleAndSubordinatesInternalIds.add( roleAndSubordinatesInternalNamesMap.get( name ).Id );
                    }
                }

            }

            System.debug( folderMembership );

            folderMemberships.add( folderMembership );

        }

        return folderMemberships;
    }

    public MetadataService.ReadDocumentFolderResult getDocumentFolderMetadata( List<String> folderDeveloperNames ) {

        MetadataService.MetadataPort service = createService();

        return (MetadataService.ReadDocumentFolderResult) service.readMetadata( 'DocumentFolder', folderDeveloperNames );
    }

    private MetadataService.MetadataPort createService() {

        // Because we will make Metadata API calls in batch context,
        // the UserInfo.getSessionId() value will not work.
        // Therefore, we need to use Named Credential instead.
        // https://www.gscloudsolutions.com/blogpost/Using-Named-Credentials-with-the-Apex-Wrapper-Salesforce-Metadata-API-apex-mdapi

        // One quirk with Metadata API is that it returns the wrong HTTP status code
        // if the provided oauth token has expired. So we need to actually make a
        // call to the REST API first so force our token gets refreshed, then proceed.
        // https://help.salesforce.com/articleView?id=Named-credential-oauth-token-doesn-t-get-automatically-refreshed-with-Salesforce-SOAP-API-end-point&language=en_US&type=1

        MetadataService.MetadataPort service = new MetadataService.MetadataPort();

        // Step 1. Determine API version
        String apiVersion = service.endpoint_x.substringAfterLast( '/' ); // 38.0

        // Step 2. Ensure oauth token is refreshed
        HttpRequest req = new HttpRequest();
        req.setEndpoint( String.format( 'callout:{0}/services/data/v{1}', new String[] { this.namedCredential, apiVersion } ) );
        req.setMethod( 'GET' );
        System.debug( req );
        HttpResponse res = new Http().send( req );
        System.debug( res );
        System.debug( res.getBody() );

        // Step 3. Create metadata service
        service.endpoint_x = String.format( 'callout:{0}/services/{1}', new String[] { this.namedCredential, service.endpoint_x.substringAfter( '/services/' ) } );
        service.SessionHeader = new MetadataService.SessionHeader_element();
        //service.SessionHeader.sessionId = UserInfo.getSessionId();
        service.SessionHeader.sessionId = '{!$Credential.OAuthToken}';

        return service;
    }

    // -----------------------------------------------------

    /**
     * Advisable to always use the other method that allows filtering by type
     * unless you are 100% positive that the developer names are unique in the whole object.
     * Which is the case for the special access groups: AllInternalUsers, AllPartnerUsers, and AllCustomerPortalUsers.
     */
    private List<Group> getGroupsByDeveloperName( Set<String> developerNames ) {
        return [ SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN :developerNames ];
    }

    private List<Group> getGroupsByDeveloperNameAndType( Set<String> developerNames, String type ) {
        return [ SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN :developerNames AND Type = :type ];
    }

    private Map<String, Group> toMapByDeveloperName( List<Group> records ) {
        return (Map<String, Group>) Doc2File_SObjectUtils.toMapByKeyField( Group.DeveloperName, records );
    }

    // -----------------------------------------------------

    public class DocumentFolderMembership {

        public String folderName { get; set; }
        public String folderDeveloperName { get; set; }
        public String accessType { get; set; } // Public, PublicInternal, Shared, Hidden
        public String publicFolderAccess { get; set; } // ReadOnly, ReadWrite

        // Groups when accessType is Public or PublicInternal
        public List<String> publicAccessGroupNames { get; set; }
        public List<String> publicAccessGroupIds { get; set; }

        // Group developer names for each sharedTo type
        public List<String> sharedToPublicGroupNames { get; set; }
        public List<String> sharedToPortalRoleNames { get; set; }
        public List<String> sharedToPortalRoleAndSubordinatesNames { get; set; }
        public List<String> sharedToRoleNames { get; set; }
        public List<String> sharedToRoleAndSubordinatesNames { get; set; }
        public List<String> sharedToRoleAndSubordinatesInternalNames { get; set; }

        // Group ids for each sharedTo type
        public List<ID> sharedToPublicGroupIds { get; set; }
        public List<ID> sharedToPortalRoleIds { get; set; }
        public List<ID> sharedToPortalRoleAndSubordinatesIds { get; set; }
        public List<ID> sharedToRoleIds { get; set; }
        public List<ID> sharedToRoleAndSubordinatesIds { get; set; }
        public List<ID> sharedToRoleAndSubordinatesInternalIds { get; set; }

        public List<ID> getAllGroupIds() {

            List<ID> groupIds = new List<ID>();

            if ( publicAccessGroupIds != null ) {
                groupIds.addAll( publicAccessGroupIds );
            }

            if ( sharedToPublicGroupIds != null ) {
                groupIds.addAll( sharedToPublicGroupIds );
            }

            if ( sharedToPortalRoleIds != null ) {
                groupIds.addAll( sharedToPortalRoleIds );
            }

            if ( sharedToPortalRoleAndSubordinatesIds != null ) {
                groupIds.addAll( sharedToPortalRoleAndSubordinatesIds );
            }

            if ( sharedToRoleIds != null ) {
                groupIds.addAll( sharedToRoleIds );
            }

            if ( sharedToRoleAndSubordinatesIds != null ) {
                groupIds.addAll( sharedToRoleAndSubordinatesIds );
            }

            if ( sharedToRoleAndSubordinatesInternalIds != null ) {
                groupIds.addAll( sharedToRoleAndSubordinatesInternalIds );
            }

            return groupIds;
        }

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
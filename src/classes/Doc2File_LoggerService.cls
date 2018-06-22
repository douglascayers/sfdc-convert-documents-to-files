/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public without sharing class Doc2File_LoggerService {

    /**
     * Designed to be called once when exception is caught
     * during a batch or queued job conversion.
     */
    public static void log( ID jobId, Exception e ) {

        System.debug( LoggingLevel.ERROR, 'jobId: ' + jobId + ', error: ' + e.getMessage() + ' : ' + e.getStackTraceString() );

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

        Doc2File_Log__c log = new Doc2File_Log__c(
            Job_ID__c = jobId,
            Status__c = 'ERROR',
            Summary__c = e.getMessage(),
            Detail__c = e.getStackTraceString()
        );

        Database.insert( log, dmo );

    }

    /**
     * Designed to be called after conversion job has run to log any errors.
     */
    public static void log( ID jobId, List<Doc2File_FolderConversionService.ConversionResult> results ) {

        List<Doc2File_Log__c> logs = new List<Doc2File_Log__c>();
        Integer maxLength = Doc2File_Log__c.Summary__c.getDescribe().getLength();

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

        for ( Doc2File_FolderConversionService.ConversionResult result : results ) {

            System.debug(
                getLoggingLevelFromSeverity( result.status ),
                'jobId: ' + jobId + ', result: ' + result
            );

            List<String> messagesAsList = new List<String>( result.messages );
            String messagesAsString = String.join( messagesAsList, '\n' );

            logs.add( new Doc2File_Log__c(
                Job_ID__c = jobId,
                Status__c = String.valueOf( result.status ),
                Old_Document_ID__c = null,
                New_File_ID__c = null,
                Summary__c = ( messagesAsList.size() > 0 ? messagesAsList[0].abbreviate( maxLength ) : null ),
                Detail__c = messagesAsString
            ));

        }

        if ( logs.size() > 0 ) {
            Database.insert( logs, dmo );
        }

    }

    private static LoggingLevel getLoggingLevelFromSeverity( Doc2File_FolderConversionService.ConversionResultStatus status ) {

        LoggingLevel level = LoggingLevel.DEBUG;

        if ( status == Doc2File_FolderConversionService.ConversionResultStatus.SKIPPED ) {
            level = LoggingLevel.WARN;
        } else if ( status == Doc2File_FolderConversionService.ConversionResultStatus.ERROR ) {
            level = LoggingLevel.ERROR;
        }

        return level;
    }

    // --------------------------------------------------------------------

    /**
     * Checks if any log records have been created since the job started.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( ID jobId ) {

        AsyncApexJob job = [ SELECT Id, CreatedDate FROM AsyncApexJob WHERE Id = :jobId ];

        sendApexExceptionEmailIfAnyErrorsSince( job.CreatedDate );

    }

    /**
     * Checks if any log records have been created since the given date/time.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( DateTime sinceDateTime ) {

        Integer count = [ SELECT count() FROM Doc2File_Log__c WHERE CreatedDate >= :sinceDateTime AND Status__c = 'ERROR' ];

        if ( count > 0 ) {

            List<ID> usersToNotify = new List<ID>();

            for ( ApexEmailNotification notif : [ SELECT UserId FROM ApexEmailNotification WHERE UserId != null LIMIT 100 ] ) {
                usersToNotify.add( notif.UserId );
            }

            if ( usersToNotify.size() > 0 ) {

                String subject = 'Errors: Convert File Tags to Topics';
                String message = 'Errors have occurred. Please review the log records for more details ' +
                                 URL.getSalesforceBaseURL().toExternalForm() + '/' + Doc2File_Log__c.sObjectType.getDescribe().getKeyPrefix();

                Doc2File_EmailService.sendEmail( usersToNotify, subject, message );

            }

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
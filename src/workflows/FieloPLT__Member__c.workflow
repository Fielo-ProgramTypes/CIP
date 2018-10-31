<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Member_registration</fullName>
        <description>Member registration</description>
        <protected>false</protected>
        <recipients>
            <field>FieloPLT__Email__c</field>
            <type>email</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/CommunityWelcomeEmailTemplate</template>
    </alerts>
    <fieldUpdates>
        <fullName>Member_Status_Approved</fullName>
        <field>FieloPLT__Status__c</field>
        <literalValue>Active</literalValue>
        <name>Member Status-Approved</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Member_Status_Rejected</fullName>
        <field>FieloPLT__Status__c</field>
        <literalValue>Rejected</literalValue>
        <name>Member Status-Rejected</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
</Workflow>

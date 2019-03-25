// This procedure.dsl was generated automatically
// It will not be updated upon regeneration
// Additional code may be a added here
procedure 'Sample Procedure', description: 'Sample procedure description', {

    step 'Sample Procedure', {
        description = ''
        command = new File("dsl/procedures/SampleProcedure/steps/SampleProcedure.pl").text
        shell = 'ec-perl'
        
        
        
    }
    
    formalOutputParameter 'deployed',
        description: 'JSON representation of the deployed application'
    

}

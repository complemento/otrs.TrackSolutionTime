package Kernel::System::GenericAgent::SetSolutionTimeField;

use strict;
use warnings;

use Kernel::System::DynamicField;
use Kernel::System::DynamicField::Backend;

#use Kernel::System::Priority;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicFieldBackend',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);
#Obrigatório:
#Date - Nome do Campo Dinamico onde deve ser armazenado a data e hora (o campo dinamico deve ser do tipo DateTime)

#Um dos dois abaixo obrigatórios, podendo inclusive ser os dois campos:
#AgentLogin - Nome do campo dinâmico onde devemos armazenar o Login do usuário que executou a ação
#AgentFullname - Concatenação do UserFirstname + " " + UserLastname do usuário que executou a ação

#Opcional
#Overwrite - "Yes" (Padrão) e "No". Caso marcado "No" o sistema verifica se o campo dinamico especificado no parametro "Date" já está preenchido. Se já estiver, a execução do módulo é interrompida.

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DynamicFieldObject}         = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{LogObject}                  = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TimeObject}                 = $Kernel::OM->Get('Kernel::System::Time');
    $Self->{TicketObject}               = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{DynamicFieldBackendObject}  = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}



sub Run {
    my ( $Self, %Param ) = @_;
    
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
    my $Overwrite = "Yes";
    
    # check needed param
    if ( !$Param{New}->{'SolutionTime'} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need SolutionTime param for GenericAgent module!',
        );
        return;
    }
    

    #INFORMAÇÔES DO CHAMADO

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        %Param,
        DynamicFields => 1,
    );

	if(defined $Ticket{SolutionTime}){
		
		#Preenchimento de Solution Time

		my $DynamicFieldSolutionTime = $DynamicFieldObject->DynamicFieldGet(
			Name => $Param{New}->{SolutionTime},
		);
		
		my $Success = $DynamicFieldBackendObject->ValueSet(
			DynamicFieldConfig => $DynamicFieldSolutionTime,      # complete config of the DynamicField
			 ObjectID           => $Ticket{TicketID},                # ID of the current object that the field
											   # must be linked to, e. g. TicketID
			 Value              => $Ticket{SolutionTime}/60  ,                   # Value to store, depends on backend type
			 UserID             => 1,
		);
	}
	
}

1;

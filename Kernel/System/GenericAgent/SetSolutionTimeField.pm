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

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
    my $Overwrite = "Yes";    

    #INFORMAÇÔES DO CHAMADO

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        %Param,
        DynamicFields => 0,
        Extended => 1,
    );

    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
       Name => 'SolutionTime'
    );

    my $DynamicFieldIsCalc = $DynamicFieldObject->DynamicFieldGet(
       Name => 'IsSolutionTimeSLAStoppedCalculated'
    );

    my $DynamicFieldTotalTime = $DynamicFieldObject->DynamicFieldGet(
       Name => 'TotalTime'
    );

    my $DynamicFieldPercentualScaleSLA = $DynamicFieldObject->DynamicFieldGet(
		Name => "PercentualScaleSLA",
	);

	if(defined $Ticket{SLA}){
		
		#Preenchimento de Solution Time
        if($Ticket{StateType} eq 'closed'){
            my $PendSumTime = $TicketObject->GetTotalNonEscalationRelevantBusinessTime(
                TicketID => $Ticket{TicketID},
            )||0;

            my %Escalation = $TicketObject->TicketEscalationPreferences(
                Ticket => \%Ticket,
                UserID => 1,
            );

            my $Success = $DynamicFieldValueObject->ValueSet(
                FieldID  => $DynamicField->{ID},
                ObjectID => $Ticket{TicketID},
                Value    => [
                    {
                            ValueText          => $Ticket{SolutionDiffInMin}
                    },
                ],
                UserID   => 1,
            );

            $Success = $DynamicFieldValueObject->ValueSet(
                FieldID  => $DynamicFieldTotalTime->{ID},
                ObjectID => $Ticket{TicketID},
                Value    => [
                    {
                            ValueText          => $Ticket{SolutionInMin}-$PendSumTime
                    },
                ],
                UserID   => 1,
            );

            my $percent = 0;
            if($Escalation{SolutionTime} != 0){
                $percent = ($Ticket{SolutionInMin} * 100) / $Escalation{SolutionTime};
            }

            $Success = $DynamicFieldValueObject->ValueSet(
                FieldID  => $DynamicFieldPercentualScaleSLA->{ID},
                ObjectID => $Ticket{TicketID},
                Value    => [
                    {
                            ValueText          => $Self->ConvertPercentualSLAScale(Value=>$percent)
                    },
                ],
                UserID   => 1,
            );
        }
        else{
            my $notIsSLAStopped = ($TimeObject->TimeStamp2SystemTime(
                String => $Ticket{SolutionTimeDestinationDate},
            ) != 1767139200);

            my $PendSumTime = $TicketObject->GetTotalNonEscalationRelevantBusinessTime(
                TicketID => $Ticket{TicketID},
            )||0;

            if($notIsSLAStopped){
                my $Success = $DynamicFieldValueObject->ValueSet(
                    FieldID  => $DynamicField->{ID},
                    ObjectID => $Ticket{TicketID},
                    Value    => [
                        {
                                ValueText          => $Ticket{SolutionTimeWorkingTime}/60
                        },
                    ],
                    UserID   => 1,
                );

                my %Escalation = $TicketObject->TicketEscalationPreferences(
                    Ticket => \%Ticket,
                    UserID => 1,
                );

                my $WorkingTime = $TimeObject->WorkingTime(
                    StartTime => $TimeObject->TimeStamp2SystemTime(
                        String => $Ticket{Created},
                    ),
                    StopTime  => $TimeObject->SystemTime(),
                    Calendar  => $Escalation{Calendar},
                )-$PendSumTime;

                $DynamicFieldValueObject->ValueSet(
                    FieldID  => $DynamicFieldTotalTime->{ID},
                    ObjectID => $Ticket{TicketID},
                    Value    => [
                        {
                                ValueText          => $WorkingTime/60
                        },
                    ],
                    UserID   => 1,
                );

                my $percent = 0;
                if($Escalation{SolutionTime} != 0){
                    $percent = (($WorkingTime/60) * 100) / $Escalation{SolutionTime};
                }

                $Success = $DynamicFieldValueObject->ValueSet(
                    FieldID  => $DynamicFieldPercentualScaleSLA->{ID},
                    ObjectID => $Ticket{TicketID},
                    Value    => [
                        {
                                ValueText          => $Self->ConvertPercentualSLAScale(Value=>$percent)
                        },
                    ],
                    UserID   => 1,
                );

                $DynamicFieldValueObject->ValueSet(
                    FieldID  => $DynamicFieldIsCalc->{ID},
                    ObjectID => $Ticket{TicketID},
                    Value    => [
                        {
                                ValueInt          => 0
                        },
                    ],
                    UserID   => 1,
                );
            }
            else{
                my $ValueIsCalc = $DynamicFieldValueObject->ValueGet(
                    FieldID            => $DynamicFieldIsCalc->{ID},
                    ObjectID           => $Ticket{TicketID},               
                );

                my $isCalculated = 0;

                if(defined $ValueIsCalc->[0]->{ValueInt}){
                    $isCalculated = $ValueIsCalc->[0]->{ValueInt};
                }

                if($isCalculated == 0){
                    my %Escalation = $TicketObject->TicketEscalationPreferences(
                        Ticket => \%Ticket,
                        UserID => 1,
                    );
                    my $DestinationTime = $TimeObject->DestinationTime(
                        StartTime => $TimeObject->TimeStamp2SystemTime(
                            String => $Ticket{Created},
                        ),
                        # 
                        # Time     => $Escalation{SolutionTime} * 60,
                        Time     => $Escalation{SolutionTime} * 60 + $PendSumTime,
                        # 
                        Calendar => $Escalation{Calendar},
                    );
                    my $SolutionTime = 0;
                    if($TimeObject->SystemTime() < $DestinationTime){
                        $SolutionTime = $TimeObject->WorkingTime(
                            StartTime => $TimeObject->SystemTime(),
                            StopTime  => $DestinationTime,
                            Calendar  => $Escalation{Calendar},
                        );
                    }
                    else{
                        $SolutionTime = $TimeObject->WorkingTime(
                            StartTime => $DestinationTime,
                            StopTime  => $TimeObject->SystemTime(),
                            Calendar  => $Escalation{Calendar},
                        )*-1;
                    }

                    my $Success = $DynamicFieldValueObject->ValueSet(
                        FieldID  => $DynamicField->{ID},
                        ObjectID => $Ticket{TicketID},
                        Value    => [
                            {
                                    ValueText          => $SolutionTime/60
                            },
                        ],
                        UserID   => 1,
                    );

                    my $WorkingTime = $TimeObject->WorkingTime(
                        StartTime => $TimeObject->TimeStamp2SystemTime(
                            String => $Ticket{Created},
                        ),
                        StopTime  => $TimeObject->SystemTime(),
                        Calendar  => $Escalation{Calendar},
                    )-$PendSumTime;

                    $DynamicFieldValueObject->ValueSet(
                        FieldID  => $DynamicFieldTotalTime->{ID},
                        ObjectID => $Ticket{TicketID},
                        Value    => [
                            {
                                    ValueText          => $WorkingTime/60
                            },
                        ],
                        UserID   => 1,
                    );

                    my $percent = 0;
                    if($Escalation{SolutionTime} != 0){
                        $percent = (($WorkingTime/60) * 100) / $Escalation{SolutionTime};
                    }

                    $Success = $DynamicFieldValueObject->ValueSet(
                        FieldID  => $DynamicFieldPercentualScaleSLA->{ID},
                        ObjectID => $Ticket{TicketID},
                        Value    => [
                            {
                                    ValueText          => $Self->ConvertPercentualSLAScale(Value=>$percent)
                            },
                        ],
                        UserID   => 1,
                    );

                    $DynamicFieldValueObject->ValueSet(
                        FieldID  => $DynamicFieldIsCalc->{ID},
                        ObjectID => $Ticket{TicketID},
                        Value    => [
                            {
                                    ValueInt          => 1
                            },
                        ],
                        UserID   => 1,
                    );
                }
            }
        }
	}
	
}

sub ConvertPercentualSLAScale{
    my ( $Self, %Param ) = @_;

    my $DynamicFieldBackendObject  = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $DynamicFieldPercentualScaleSLA = $DynamicFieldObject->DynamicFieldGet(
		Name => "PercentualScaleSLA",
	);

    my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
       DynamicFieldConfig => $DynamicFieldPercentualScaleSLA,
    );

    foreach my $key (keys %{$PossibleValues}){
        my $indexOf = index($key,'-');
        if($indexOf > -1){
            my $min = substr $key, 0, $indexOf;
            my $max = substr $key, $indexOf+1;

            if($Param{Value} >= $min && $Param{Value} < $max){
                return $key;
            }
        }
        $indexOf = index($key,'>');
        if($indexOf > -1){
            my $number = substr $key, $indexOf+1;
            if($Param{Value} > $number){
                return $key;
            }
        }
        $indexOf = index($key,'<');
        if($indexOf > -1){
            my $number = substr $key, $indexOf+1;
            if($Param{Value} < $number){
                return $key;
            }
        }
    }
    
    return "";
}

1;

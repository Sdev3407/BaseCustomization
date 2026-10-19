pageextension 50252 "CustomerLists_Ext" extends "Customer List"
{
    layout { }
    actions
    {
        addafter("Customer List")
        {
            Action("Download Payment QR Code")
            {
                ApplicationArea = All;
                PromotedCategory = Process;
                Promoted = true;
                //Visible = DisableOnFeedPlant;
                trigger OnAction()
                var
                    OutStream: OutStream;
                    InStream: InStream;
                    Cust: Record Customer;
                    FileName: Text;
                    Base64: Codeunit "Base64 Convert";
                    APIFunction: Codeunit "API Functions";
                    TempBlob: Codeunit "Temp Blob";
                begin

                    FileName := 'QR_' + Cust."No." + '.jpg';
                    Cust.Reset();
                    Cust.SetRange("No.", Rec."No.");
                    Cust.Setfilter("Customer Type", '<>%1', Cust."Customer Type"::Farmer);
                    if Cust.FindFirst() Then begin

                        TempBlob.CreateOutStream(OutStream);
                        Base64.FromBase64(APIFunction.GeneratePaymentQRCOdeforCustomer(Cust."No."), OutStream);
                        FileName := 'QR_' + Cust."No." + '.jpg';
                        TempBlob.CreateInStream(InStream);
                        Cust.PaymentQR.CreateOutStream(OutStream);
                        CopyStream(OutStream, InStream);
                        Cust.Modify();
                        Cust.CalcFields(PaymentQR);
                        Cust."PaymentQR".CreateInStream(InStream);
                        DownloadFromStream(InStream, 'Download QR', '', '', FileName)
                    end;
                end;
            }
            Action("Generate Payment QR COde")
            {
                ApplicationArea = All;
                PromotedCategory = Process;
                Promoted = true;
                //Visible = DisableOnFeedPlant;

                trigger OnAction()
                var
                    APIFunction: Codeunit "API Functions";
                    Response: Text;
                    Base64: Codeunit "Base64 Convert";
                    //DotNetBase64: DotNet System.Convert;
                    // Bytes: DotNet ArrayByte;
                    // MemoryStream: DotNet MemoryStream;
                    OutStream: OutStream;
                    InStream: InStream;
                    TempBlob: Codeunit "Temp Blob";
                    FileName: Text;
                    FilePath: Text;
                    Cust: Record Customer;
                    FileManagement: Codeunit "File Management";
                    WhatappFun: Codeunit "WhatsApp Function";
                    BankAccount: Text;
                    IFSCCode: text;
                    Companyinfo: Record "Company Information";
                    WhatsappPath: Text;
                    PhoneNo: Text;
                    Salesperson: Record "Salesperson/Purchaser";
                begin
                    Cust.Reset();
                    Cust.SetRange("No.", Rec."No.");
                    Cust.Setfilter("Customer Type", '<>%1', Cust."Customer Type"::Farmer);
                    if Cust.FindFirst() Then begin
                        FilePath := 'D:\Whatsapp\' + 'QR_' + Cust."No." + '.jpg';
                        WhatsappPath := 'https://sfplwhatsapp.sampoornafeeds.in/' + 'QR_' + Cust."No." + '.jpg';
                        Cust.CalcFields("PaymentQR");
                        if Cust."PaymentQR".HasValue then begin
                            Cust."PaymentQR".CreateInStream(InStream);
                            FileName := 'QR_' + Cust."No." + '.jpg';
                            if not File.Exists(FilePath) Then
                                Cust.PaymentQR.Export(FilePath);
                        end else begin
                            TempBlob.CreateOutStream(OutStream);
                            Base64.FromBase64(APIFunction.GeneratePaymentQRCOdeforCustomer(Cust."No."), OutStream);
                            FileName := 'QR_' + Cust."No." + '.jpg';
                            TempBlob.CreateInStream(InStream);
                            Cust.PaymentQR.CreateOutStream(OutStream);
                            CopyStream(OutStream, InStream);
                            Cust.Modify();
                            Cust.CalcFields(PaymentQR);
                            Cust.PaymentQR.Export(FilePath);
                        end;
                        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then begin
                            if Cust."Responsibility Center" = 'FEED' Then begin
                                BankAccount := 'SFFD01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = 'BREEDER' Then begin
                                BankAccount := 'SFBR01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = 'CBF' Then begin
                                BankAccount := 'SFCB01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = 'CATTLE' Then begin
                                BankAccount := 'SFCT01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = 'HATCH' Then begin
                                BankAccount := 'SFHT01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = 'SWINE' Then begin
                                BankAccount := 'SFSW01' + Cust."No.";
                            end;
                            if Cust."Responsibility Center" = '' Then begin
                                BankAccount := 'SFFD01' + Cust."No.";
                            end;
                            IFSCCode := 'HDFC0000055';
                            if Cust."WhatsApp Mobile No." <> '' then
                                PhoneNo := Cust."Phone No."
                            else
                                PhoneNo := Cust."WhatsApp Mobile No.";

                            WhatappFun.AirtelWhatssAppAPI(WhatappFun.CustomerPaymentQRCODE(PhoneNo, Cust.Name, WhatsappPath, FileName, BankAccount, IFSCCode));
                            if Cust."Salesperson Code" <> '' then begin
                                Salesperson.Get(Cust."Salesperson Code");
                                WhatappFun.AirtelWhatssAppAPI(WhatappFun.CustomerPaymentQRCODE(Salesperson."Phone No.", Cust.Name, WhatsappPath, FileName, BankAccount, IFSCCode));
                            end;
                            //Erase(FilePath);
                        end;
                    end;
                end;
            }
        }
    }
}
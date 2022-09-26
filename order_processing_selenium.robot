*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Tables
Library             Collections
Library             OperatingSystem
Library             RPA.Robocloud.Secrets
Library             RPA.HTTP
Library             RPA.RobotLogListener
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Browser.Selenium


*** Variables ***
${orders_csv_url}                   https://robotsparebinindustries.com/orders.csv
${downloaded_orders_csv_file}       ${CURDIR}${/}/orders.csv
${url}                              https://robotsparebinindustries.com/#/robot-order
${img_folder}                       ${CURDIR}${/}image_files
${pdf_folder}                       ${CURDIR}${/}pdf_files
${zip_file}                         ${output_folder}${/}pdf_archive.zip
${output_folder}                    ${CURDIR}${/}output

# Form test data
${order_number_test_data}
${head_test_data}
${body_test_data}
${legs_test_data}
${address_test_data}

# Form elements
${drop_down_head}                   xpath=//select[@id='head']
${radio_groups_body}                body
${input_legs}                       xpath=//input[@placeholder="Enter the part number for the legs"]
${input_address}                    xpath=//input[@id='address']
${btn_order}                        xpath=//button[@id='order']
${btn_preview}                      xpath=//button[@id='preview']
${img_preview}                      xpath=//div[@id='robot-preview-image']
${button_yes}                       xpath=//button[contains(text(), 'OK')]
${btn_order}                        xpath=//button[@id="order"]
${lbl_receipt}                      xpath=//div[@id='receipt']
${lbl_orderid_element}              xpath=//p[@class='badge badge-success']
${btn_order_another_robot}          xpath=//*[@id="order-another"]


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Directory Cleanup

    Get Login Details From Vault
    ${orders}=    Get orders
    Navigate to robot order website
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    # Create a ZIP file of the receipts


*** Keywords ***
Directory Cleanup
    Log To console    Cleaning up content from previous test runs

    Create Directory    ${img_folder}
    Create Directory    ${pdf_folder}

    Empty Directory    ${img_folder}
    Empty Directory    ${pdf_folder}
    #Empty Directory    ${output_folder}

Get Login Details From Vault
    Log To Console    Getting Secret from our Vault
    ${login_credentials}=    Get Secret    credentials

Navigate to robot order website
    Open Browser	url=${url}	browser=Chrome
    Maximize Browser Window
    #RPA.Browser.Selenium.Maximize Browser Window
    Sleep    2s

Get orders
    RPA.HTTP.Download    url=${orders_csv_url}    target_file=${downloaded_orders_csv_file}
    ${orders_table}=    Read table from CSV    path=${downloaded_orders_csv_file}
    Log To Console    Orders data ${orders_table}
    RETURN    ${orders_table}

Close the annoying modal
    Click Button When Visible    ${button_yes}
    Sleep    5s

[Arguments]

Fill the form
    [Arguments]    ${row}

    #Data to be entered
    ${order_number_test_data}=    Set variable    ${row}[Order number]
    ${head_test_data}=    Set variable    ${row}[Head]
    ${body_test_data}=    Set variable    ${row}[Body]
    ${legs_test_data}=    Set variable    ${row}[Legs]
    ${address_test_data}=    Set variable    ${row}[Address]
    Set Local Variable    ${radio_group_body}    xpath=//*[@id='id-body-${${body_test_data}}']

    Click Element If Visible    ${drop_down_head}
    Sleep    2s
    Select From List By Value    ${drop_down_head}    ${head_test_data}
    Select Radio Button    ${radio_groups_body}    ${body_test_data}
    Input Text When Element Is Visible    ${input_legs}    ${legs_test_data}
    Input Text When Element Is Visible    ${input_address}    ${address_test_data}

Preview the robot
    Scroll Element Into View    ${btn_preview}
    Is Element Visible    ${btn_preview}
    Click Button    ${btn_preview}
    Is Element Visible    ${img_preview}

Submit the order
    Is Element Visible    ${btn_order}
    Click Button    ${btn_order}
    Sleep    3s
    #Wait Until Element Contains    //div[@id='receipt']/h3    Receipt
    Is Element Visible    ${lbl_receipt}

Store the receipt as a PDF file
    [Arguments]    ${ORDER_NUMBER}
    Log To Console    Order Number for processing ${ORDER_NUMBER}
    ${order_receipt_html}=    Get Text    ${lbl_receipt}
    Log To Console    Receipt number ${order_receipt_html}

    Set Local Variable    ${fully_qualified_pdf_filename}    ${pdf_folder}${/}${ORDER_NUMBER}.pdf

    Html To Pdf    content=${order_receipt_html}    output_path=${fully_qualified_pdf_filename}
    RETURN    ${fully_qualified_pdf_filename}

Take a screenshot of the robot
    [Arguments]    ${ORDER_NUMBER}

    Is Element Visible    ${img_preview}    visible
    Is Element Visible    ${lbl_orderid_element}    visible

    # Get the order ID
    ${orderid}=    Get Text    ${lbl_orderid_element}
    Log To Console    orderid    ${orderid}
    Log To Console    img_folder ${img_folder}
    # Take Snapshot & Create the File Name
    Set Local Variable    ${fully_qualified_img_filename}    ${img_folder}${/}${orderid}.png
    Capture Element Screenshot    ${img_preview}    ${fully_qualified_img_filename}   
    Log To Console    fully_qualified_img_filename ${fully_qualified_img_filename}

    Sleep    1sec

    Log To Console    Capturing Screenshot to ${fully_qualified_img_filename}
    RPA.Browser.Selenium.Capture Element Screenshot    ${img_preview}    ${fully_qualified_img_filename}

    #RETURN    ${orderid}    ${fully_qualified_img_filename}
    RETURN    ${fully_qualified_img_filename}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${IMG_FILE}    ${PDF_FILE}
    TRY
        Log To Console    Printing Embedding image: ${IMG_FILE}
        Log To Console    In pdf file: ${PDF_FILE}
        # Open PDF    ${PDF_FILE}
        @{myfiles}=    Create List    ${IMG_FILE}
        Add Files To PDF    ${myfiles}    ${PDF_FILE}    ${True}
        # Close PDF    ${PDF_FILE}
    EXCEPT    message
        Log To Console    message
    END

Go to order another robot
    # Define local variables for the UI elements
    Click Button    ${btn_order_another_robot}

Create a ZIP file of the receipts
    Archive Folder With Zip    ${pdf_folder}    ${zip_file}    recursive=True    include=*.pdf

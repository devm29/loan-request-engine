import { Application } from "@hotwired/stimulus"
import FlashController from "controllers/flash_controller"
import LoanRequestFormController from "controllers/loan_request_form_controller"
import TermSheetController from "controllers/term_sheet_controller"

const application = Application.start()
application.register("flash", FlashController)
application.register("loan-request-form", LoanRequestFormController)
application.register("term-sheet", TermSheetController)

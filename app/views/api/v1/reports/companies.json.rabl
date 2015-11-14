node(:companies) {Company.basic_json(@companies)}

node(:result_code) { SUCCESS_CODES[:success] }